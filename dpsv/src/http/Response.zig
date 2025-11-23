const Response = @This();
const std = @import("std");
const Io = std.Io;

pub const ok: @This() = .{ .status = 200, .message = "OK" };
pub const method_not_allowed: @This() = .{ .status = 405, .message = "Method Not Allowed" };

const status_line_fmt: []const u8 = "HTTP/1.1 {d} {s}\r\n";
const content_type_fmt: []const u8 = "Content-Type: {s}\r\n";
const content_length_fmt: []const u8 = "Content-Length: {d}\r\n";

status: u16,
message: []const u8,

pub fn respondEmpty(response: *const @This(), writer: *Io.Writer) !void {
    try response.writeStatusLine(writer);
    try writer.writeAll("\r\n");
    try writer.flush();
}

pub fn respondWithJson(response: *const @This(), writer: *Io.Writer, json: anytype) !void {
    const fmt = std.json.fmt(json, .{ .emit_null_optional_fields = false });

    try response.writeStatusLine(writer);
    try writeContentType(writer, "application/json");
    try writeContentLength(writer, fmt);
    try writer.writeAll("\r\n");
    try writer.print("{f}", .{fmt});
    try writer.flush();
}

fn writeStatusLine(response: *const @This(), writer: *Io.Writer) !void {
    try writer.print(status_line_fmt, .{ response.status, response.message });
}

fn writeContentType(writer: *Io.Writer, content_type: []const u8) !void {
    try writer.print(content_type_fmt, .{content_type});
}

fn writeContentLength(writer: *Io.Writer, content: anytype) !void {
    var counter = Io.Writer.Discarding.init("");
    try counter.writer.print("{f}", .{content});
    try writer.print(content_length_fmt, .{counter.fullCount()});
}
