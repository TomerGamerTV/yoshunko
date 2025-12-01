const std = @import("std");
const Io = std.Io;
const pb = @import("proto").pb;
const network = @import("../network.zig");
const State = @import("../network/State.zig");
const AliveTimer = @import("../network/AliveTimer.zig");
const Memory = State.Memory;
const Connection = @import("../network/Connection.zig");
const EventQueue = @import("../logic/EventQueue.zig");
const PlayerBasicComponent = @import("../logic/component/player/PlayerBasicComponent.zig");

pub fn onPlayerLoginCsReq(txn: *network.Transaction(pb.PlayerLoginCsReq), events: *EventQueue) !void {
    try events.enqueue(.login, .{});
    try txn.respond(.{ .retcode = 0 });
}

pub fn onGetSelfBasicInfoCsReq(
    txn: *network.Transaction(pb.GetSelfBasicInfoCsReq),
    basic_comp: *PlayerBasicComponent,
    mem: Memory,
) !void {
    errdefer txn.respond(.{ .retcode = 1 }) catch {};

    try txn.respond(.{
        .self_basic_info = try basic_comp.info.toProto(mem.arena),
    });
}

pub fn onKeepAliveNotify(
    _: *network.Transaction(pb.KeepAliveNotify),
    io: Io,
    alive_timer: *AliveTimer,
) !void {
    try alive_timer.reset(io);
}

pub fn onGetServerTimestampCsReq(
    txn: *network.Transaction(pb.GetServerTimestampCsReq),
    io: std.Io,
) !void {
    try txn.respond(.{
        .timestamp = @intCast((try std.Io.Clock.real.now(io)).toMilliseconds()),
        .utc_offset = 3,
    });
}

pub fn onModAvatarCsReq(
    txn: *network.Transaction(pb.ModAvatarCsReq),
    basic_comp: *PlayerBasicComponent,
    events: *EventQueue,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(pb.ModAvatarScRsp{ .retcode = retcode }) catch {};

    basic_comp.info.avatar_id = txn.message.avatar_id;
    basic_comp.info.control_avatar_id = txn.message.control_avatar_id;
    basic_comp.info.control_guise_avatar_id = txn.message.control_guise_avatar_id;

    try events.enqueue(.basic_info_modified, .{});
    retcode = 0;
}

pub fn onPlayerLogoutCsReq(
    _: *network.Transaction(pb.PlayerLogoutCsReq),
    events: *EventQueue,
    conn: *Connection,
) !void {
    conn.logout_requested = true;
    try events.enqueue(.logout, .{});
}
