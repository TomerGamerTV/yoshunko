const Request = @This();
const std = @import("std");
const Io = std.Io;

pub const Method = enum { GET, HEAD };

method: Method,
path: []const u8 = "",
query: []const u8 = "",

pub fn parse(reader: *Io.Reader) !@This() {
    const method_str = (reader.takeDelimiter(' ') catch null) orelse return error.MissingMethod;
    const method = std.meta.stringToEnum(Method, method_str) orelse return error.MethodNotSupported;

    var parsed: @This() = .{ .method = method };

    parsed.path = (reader.takeDelimiter(' ') catch null) orelse return error.MissingPath;
    parsed.query = "";

    if (std.mem.findScalar(u8, parsed.path, '?')) |query_start| {
        parsed.query = parsed.path[query_start + 1 ..];
        parsed.path = parsed.path[0..query_start];
    }

    return parsed;
}

pub const QueryIterator = struct {
    tokens: std.mem.TokenIterator(u8, .scalar),

    pub fn next(iter: *@This()) ?struct { []const u8, []const u8 } {
        return while (iter.tokens.next()) |entry| {
            const eq_index = std.mem.findScalar(u8, entry, '=') orelse continue;
            break .{ entry[0..eq_index], entry[eq_index + 1 ..] };
        } else null;
    }
};

pub fn params(request: *const Request) QueryIterator {
    return .{ .tokens = std.mem.tokenizeScalar(u8, request.query, '&') };
}

pub fn lastPathSegment(request: *const Request) []const u8 {
    return if (std.mem.findScalarLast(u8, request.path, '/')) |last_segment_begin|
        request.path[last_segment_begin + 1 ..]
    else
        request.path;
}

pub fn format(request: Request, writer: *Io.Writer) !void {
    try writer.writeAll(request.path);
    if (request.query.len != 0) {
        try writer.writeAll("?");
        try writer.writeAll(request.query);
    }
}
