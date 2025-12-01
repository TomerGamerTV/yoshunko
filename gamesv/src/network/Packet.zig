const Packet = @This();
const std = @import("std");
const Io = std.Io;

pub const head_magic: u32 = 0x01234567;
pub const tail_magic: u32 = 0x89ABCDEF;

cmd_id: u16,
head: []const u8,
body: []u8,

pub fn read(reader: *Io.Reader) !?Packet {
    const metadata = reader.peekArray(12) catch return null;
    if (std.mem.readInt(u32, metadata[0..4], .big) != head_magic) return error.MagicMismatch;
    const head_len = std.mem.readInt(u16, metadata[6..8], .big);
    const body_len = std.mem.readInt(u32, metadata[8..12], .big);
    const buffer = reader.take(16 + head_len + body_len) catch return null;

    const tail = buffer[12 + head_len + body_len ..];
    if (std.mem.readInt(u32, tail[0..4], .big) != tail_magic) return error.MagicMismatch;

    return .{
        .cmd_id = std.mem.readInt(u16, buffer[4..6], .big),
        .head = buffer[12 .. head_len + 12],
        .body = buffer[12 + head_len .. 12 + head_len + body_len],
    };
}

pub fn encodingLength(packet: Packet) usize {
    return 16 + packet.head.len + packet.body.len;
}
