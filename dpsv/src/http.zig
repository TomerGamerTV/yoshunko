const std = @import("std");
const FileSystem = @import("common").FileSystem;

const Io = std.Io;
const Allocator = std.mem.Allocator;

const Request = @import("http/Request.zig");
const Response = @import("http/Response.zig");

const query_dispatch = @import("handlers/query_dispatch.zig");
const query_gateway = @import("handlers/query_gateway.zig");
const query_dispatch_path = "/query_dispatch";
const query_gateway_prefix = "/query_gateway/";

pub fn onConnect(gpa: Allocator, io: Io, fs: *FileSystem, stream: Io.net.Stream) void {
    const log = std.log.scoped(.network);

    if (processConnection(gpa, io, fs, stream)) {
        log.debug("connection from {f} disconnected", .{stream.socket.address});
    } else |err| {
        log.err("connection from {f} disconnected due to an error: {t}", .{ stream.socket.address, err });
    }
}

fn processConnection(gpa: Allocator, io: Io, fs: *FileSystem, stream: Io.net.Stream) !void {
    const log = std.log.scoped(.network);
    defer stream.close(io);

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    log.debug("new connection from {f}", .{stream.socket.address});

    var read_buffer: [1024]u8 = undefined;
    var write_buffer: [1024]u8 = undefined;

    var reader = stream.reader(io, read_buffer[0..]);
    var writer = stream.writer(io, write_buffer[0..]);

    if (reader.interface.takeDelimiter('\r')) |line| {
        var line_reader = Io.Reader.fixed(line orelse return);

        if (Request.parse(&line_reader)) |request| {
            processRequest(arena.allocator(), &writer.interface, fs, request) catch |err| {
                log.err("failed to process request {f}: {t}", .{ request, err });
                return;
            };
        } else |err| switch (err) {
            error.MethodNotSupported => Response.method_not_allowed.respondEmpty(
                &writer.interface,
            ) catch {},
            else => {
                log.err(
                    "client from {f} sent a malformed request: {t}",
                    .{ stream.socket.address, err },
                );
                return;
            },
        }
    } else |err| switch (err) {
        error.ReadFailed => {
            if (reader.err.? == error.EndOfStream) return;
            return err;
        },
        else => return err,
    }
}

fn processRequest(arena: Allocator, writer: *Io.Writer, fs: *FileSystem, request: Request) !void {
    const log = std.log.scoped(.http);

    if (std.mem.eql(u8, request.path, query_dispatch_path)) {
        try query_dispatch.process(arena, writer, fs, request);
    } else if (std.mem.startsWith(u8, request.path, query_gateway_prefix) and std.mem.countScalar(u8, request.path, '/') == 2) {
        try query_gateway.process(arena, writer, fs, request);
    } else {
        try (Response{
            .status = 599,
            .message = "Service Unavailable",
        }).respondEmpty(writer);

        log.warn("ignoring request of unknown path: '{s}'", .{request.path});
    }
}
