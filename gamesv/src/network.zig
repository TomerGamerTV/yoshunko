const std = @import("std");
const proto = @import("proto");
const common = @import("common");
const handlers = @import("handlers.zig");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const FileSystem = common.FileSystem;
const Assets = @import("data/Assets.zig");
const EventQueue = @import("logic/EventQueue.zig");

const State = @import("network/State.zig");
const Packet = @import("network/Packet.zig");
const AliveTimer = @import("network/AliveTimer.zig");
const Connection = @import("network/Connection.zig");
const auth = @import("network/auth.zig");
const PlayerComponentStorage = @import("fs/PlayerComponentStorage.zig");

const xorpad_len: usize = 4096;
const log = std.log.scoped(.network);

pub fn onConnect(gpa: Allocator, io: Io, fs: *FileSystem, assets: *const Assets, stream: Io.net.Stream) void {
    if (processConnection(gpa, io, fs, assets, stream)) {
        log.debug("connection from {f} disconnected", .{stream.socket.address});
    } else |err| if (err != error.Canceled) {
        log.debug("connection from {f} disconnected due to an error: {t}", .{ stream.socket.address, err });
    }
}

pub fn Transaction(comptime Message: type) type {
    return struct {
        const Txn = @This();
        pub const MessageType = Message;

        pub const Response = blk: {
            const message_name = @typeName(Message)[3..];
            if (!(std.mem.endsWith(u8, message_name, "CsReq"))) break :blk void;
            const response_name = message_name[0 .. message_name.len - 5] ++ "ScRsp";
            if (!@hasDecl(proto.pb, response_name)) break :blk void;
            break :blk @field(proto.pb, response_name);
        };

        message: Message,
        conn: *Connection,
        response: ?Response,

        pub fn respond(txn: *Txn, rsp: Response) !void {
            if (txn.response != null) return error.RepeatedResponse; // tried to call respond twice
            txn.response = rsp;
        }

        pub fn notify(txn: Txn, ntf: anytype) !void {
            try txn.conn.write(ntf, 0);
        }
    };
}

fn processConnection(gpa: Allocator, io: Io, fs: *FileSystem, assets: *const Assets, stream: Io.net.Stream) !void {
    defer stream.close(io);

    log.debug("new connection from {f}", .{stream.socket.address});

    var xorpad = try fs.readFile(gpa, "xorpad/bytes") orelse return error.MissingXorpadFile;
    defer gpa.free(xorpad);

    if (xorpad.len != xorpad_len) return error.InvalidXorpadFile;

    const conn = try gpa.create(Connection);
    defer gpa.destroy(conn);

    conn.init(io, stream, xorpad);
    defer conn.deinit(gpa);

    const first_packet, _ = (try nextPacket(conn, true, false)) orelse return;
    const player_uid = try handleFirstPacket(conn, fs, first_packet, gpa);

    var player_components = try PlayerComponentStorage.init(gpa, fs, assets, player_uid);
    defer player_components.deinit(gpa);

    const player_data_path = try std.fmt.allocPrint(gpa, "player/{}/", .{player_uid});
    defer gpa.free(player_data_path);

    var state: State = .{
        .io = io,
        .fs = fs,
        .assets = assets,
        .conn = conn,
        .gpa = gpa,
        .arena = .init(gpa),
        .player_uid = player_uid,
        .alive_timer = try .init(io),
        .player_components = &player_components,
        .player_sync_notify = .{},
    };

    defer state.arena.deinit();
    defer state.deinit(gpa);

    while (!conn.logout_requested) : ({
        conn.writer.interface.flush() catch {};
        _ = state.arena.reset(.free_all);
        state.player_sync_notify = .{};
    }) {
        var next_packet = try io.concurrent(nextPacket, .{ conn, true, true });
        defer _ = next_packet.cancel(io) catch {};

        var fs_changes = try io.concurrent(FileSystem.waitForChanges, .{ fs, player_data_path });
        defer if (fs_changes.cancel(io)) |changes| changes.deinit() else |_| {};

        var alive_timeout = try io.concurrent(AliveTimer.wait, .{ &state.alive_timer, io });
        defer alive_timeout.cancel(io) catch {};

        switch (try io.select(.{ .next_packet = &next_packet, .fs_changes = &fs_changes, .timeout = &alive_timeout })) {
            .next_packet => |fallible| {
                _ = fallible catch |err| switch (err) {
                    error.EndOfStream => return,
                    else => return err,
                };

                while (nextPacket(conn, false, false)) |pk| {
                    const packet, const head = pk.?;
                    log.debug("received packet with cmd_id: {}, packet_id: {}", .{ packet.cmd_id, head.packet_id });

                    handlers.dispatchPacket(&state, head, &packet) catch |err| switch (err) {
                        error.HandlerNotFound => {
                            log.warn("no handler for cmd_id {}", .{packet.cmd_id});
                            if (head.packet_id != 0) try state.conn.writeDummy(head.packet_id);
                        },
                    };
                } else |err| switch (err) {
                    error.WouldBlock => continue,
                    else => return err,
                }
            },
            .fs_changes => |fallible| {
                const changes = fallible catch continue;
                var event_queue: EventQueue = .{ .arena = state.arena.allocator() };

                for (changes.files) |file| {
                    try event_queue.enqueue(.state_file_modified, .{
                        .path = file.path[player_data_path.len..],
                        .content = fs.readFile(state.arena.allocator(), file.path) catch continue orelse continue,
                    });
                }

                handlers.drainEventQueue(&event_queue, &state) catch continue;
            },
            .timeout => {
                log.debug("keep alive timeout exceeded, disconnecting client", .{});
                return;
            },
        }
    }
}

fn handleFirstPacket(conn: *Connection, fs: *FileSystem, packet: Packet, gpa: Allocator) !u32 {
    @setEvalBranchQuota(10_000);

    if (packet.cmd_id != proto.pb_desc.PlayerGetTokenCsReq.cmd_id) return error.UnexpectedCmdID;

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var reader = Io.Reader.fixed(packet.body);
    const request = try proto.decodeMessage(&reader, arena.allocator(), proto.pb.PlayerGetTokenCsReq, proto.pb_desc);
    const result = try auth.playerGetToken(conn, arena.allocator(), fs, request);

    try conn.writer.interface.flush();
    common.random.getMtDecryptVector(result.rand_key, conn.xorpad);
    return result.player_uid;
}

fn nextPacket(conn: *Connection, block: bool, wake_only: bool) !?struct { Packet, proto.pb.PacketHead } {
    while (true) {
        var reader = Io.Reader.fixed(conn.reader.interface.buffered());
        const packet = (try Packet.read(&reader)) orelse {
            if (!block) return error.WouldBlock;

            try conn.reader.interface.fillMore();
            continue;
        };

        if (wake_only) return null;

        conn.reader.interface.discardAll(packet.encodingLength()) catch unreachable;
        xor(packet.body, conn.xorpad);

        var head_reader = Io.Reader.fixed(packet.head);
        const head = try proto.decodeMessage(
            &head_reader,
            Allocator.failing, // PacketHead doesn't need allocation
            proto.pb.PacketHead,
            proto.pb.desc_common,
        );

        return .{ packet, head };
    }
}

inline fn xor(buffer: []u8, xorpad: []const u8) void {
    for (0..buffer.len) |i| buffer[i] ^= xorpad[i % xorpad_len];
}
