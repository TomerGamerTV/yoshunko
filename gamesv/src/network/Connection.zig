const Connection = @This();
const std = @import("std");
const proto = @import("proto");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Packet = @import("Packet.zig");

stream: Io.net.Stream,
reader: Io.net.Stream.Reader,
writer: XoringWriter,
xorpad: []u8,
recv_buffer: [32678]u8 = undefined, // TODO: make it resizable
send_buffer: [8192]u8 = undefined,
outgoing_packet_id_counter: u32 = 0,
logout_requested: bool = false,

pub fn init(
    connection: *Connection,
    io: Io,
    stream: Io.net.Stream,
    xorpad: []u8,
) void {
    connection.* = .{
        .xorpad = xorpad,
        .stream = stream,
        .reader = stream.reader(io, connection.recv_buffer[0..]),
        .writer = XoringWriter.init(connection.send_buffer[0..], xorpad, stream.writer(io, "")),
    };
}

pub fn deinit(connection: *Connection, gpa: Allocator) void {
    _ = connection;
    _ = gpa;
}

pub fn write(connection: *Connection, message: anytype, ack_packet_id: u32) !void {
    return connection.writeMessage(message, proto.pb_desc, ack_packet_id);
}

pub fn writeDummy(connection: *Connection, ack_packet_id: u32) !void {
    return connection.writeMessage(proto.pb.DummyMessage{}, proto.pb.desc_common, ack_packet_id);
}

fn writeMessage(connection: *Connection, message: anytype, desc_set: type, ack_packet_id: u32) !void {
    const Message = @TypeOf(message);
    const message_name = @typeName(Message)[3..];
    if (!@hasDecl(desc_set, message_name)) {
        std.log.debug("trying to send a message which is not defined in descriptor set: {s}, falling back to dummy", .{message_name});
        return connection.writeDummy(ack_packet_id);
    }

    const message_desc = @field(desc_set, message_name);
    const packet_head: proto.pb.PacketHead = .{
        .packet_id = connection.outgoing_packet_id_counter,
        .ack_packet_id = ack_packet_id,
    };

    connection.outgoing_packet_id_counter += 1;
    const w = &connection.writer.interface;
    try w.writeInt(u32, Packet.head_magic, .big);
    try w.writeInt(u16, message_desc.cmd_id, .big);
    try w.writeInt(u16, @intCast(proto.encodingLength(packet_head, proto.pb.desc_common)), .big);
    try w.writeInt(u32, @intCast(proto.encodingLength(message, desc_set)), .big);
    try proto.encodeMessage(w, packet_head, proto.pb.desc_common);
    connection.writer.pushXorStartIndex();
    try proto.encodeMessage(w, message, desc_set);
    connection.writer.popXorStartIndex();
    try w.writeInt(u32, Packet.tail_magic, .big);
}

const XoringWriter = struct {
    xor_start_index: ?usize = null,
    xorpad_index: ?usize = null,
    interface: Io.Writer,
    underlying_stream: Io.net.Stream.Writer,
    xorpad: []const u8,

    pub fn init(buffer: []u8, xorpad: []const u8, underlying_stream: Io.net.Stream.Writer) @This() {
        return .{
            .underlying_stream = underlying_stream,
            .xorpad = xorpad,
            .interface = .{ .buffer = buffer, .vtable = &.{ .drain = @This().drain } },
        };
    }

    pub fn pushXorStartIndex(self: *@This()) void {
        if (self.xor_start_index == null) self.xor_start_index = self.interface.end;
    }

    pub fn popXorStartIndex(self: *@This()) void {
        if (self.xor_start_index) |index| {
            const buf = self.interface.buffered()[index..];
            const xorpad_index = self.xorpad_index orelse 0;

            for (0..buf.len) |i| {
                buf[i] ^= self.xorpad[(xorpad_index + i) % 4096];
            }

            self.xor_start_index = null;
            self.xorpad_index = null;
        }
    }

    fn drain(w: *Io.Writer, data: []const []const u8, _: usize) Io.Writer.Error!usize {
        const this: *@This() = @alignCast(@fieldParentPtr("interface", w));
        const buf = w.buffered();
        w.end = 0;

        if (this.xor_start_index) |index| {
            var xorpad_index = this.xorpad_index orelse 0;

            const slice = buf[index..];
            for (0..slice.len) |i| {
                slice[i] ^= this.xorpad[xorpad_index % 4096];
                xorpad_index += 1;
            }

            this.xor_start_index = 0;
            this.xorpad_index = xorpad_index;
        }

        try this.underlying_stream.interface.writeAll(buf);

        @memcpy(w.buffer[0..data[0].len], data[0]);
        w.end = data[0].len;

        return buf.len;
    }
};
