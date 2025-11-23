const Client = @This();
const Io = @import("std").Io;

stream: Io.net.Stream,
reader: Io.net.Stream.Reader,
buffer: [4096]u8 = undefined,

pub fn init(client: *Client, io: Io, stream: Io.net.Stream) void {
    client.* = .{
        .stream = stream,
        .reader = stream.reader(io, client.buffer[0..]),
    };
}

pub fn deinit(client: *Client, io: Io) void {
    client.stream.close(io);
}
