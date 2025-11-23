const std = @import("std");
const common = @import("common");
const zon = std.zon;
const Allocator = std.mem.Allocator;
const FileSystem = common.FileSystem;

pub fn parseZon(comptime T: type, gpa: Allocator, content: []const u8) !T {
    var diagnostics: zon.parse.Diagnostics = .{};
    defer diagnostics.deinit(gpa);

    return zon.parse.fromSliceAlloc(T, gpa, @ptrCast(content), &diagnostics, .{}) catch {
        std.log.err("failed to parse {s}:\n{f}", .{ @typeName(T), diagnostics });
        return error.ParseFailed;
    };
}

pub fn serializeZon(arena: Allocator, data: anytype) ![]u8 {
    var allocating = std.Io.Writer.Allocating.init(arena);
    try zon.stringify.serialize(data, .{}, &allocating.writer);
    return allocating.written();
}

pub fn loadZon(
    comptime T: type,
    gpa: Allocator,
    arena: Allocator,
    fs: *FileSystem,
    comptime path_fmt: []const u8,
    fmt_args: anytype,
) !?T {
    const path = try std.fmt.allocPrint(arena, path_fmt, fmt_args);
    if (try fs.readFile(arena, path)) |data| {
        return try parseZon(T, gpa, data);
    } else return null;
}

pub fn loadOrCreateZon(
    comptime T: type,
    gpa: Allocator,
    arena: Allocator,
    fs: *FileSystem,
    comptime path_fmt: []const u8,
    fmt_args: anytype,
) !T {
    const path = try std.fmt.allocPrint(arena, path_fmt, fmt_args);
    if (try fs.readFile(arena, path)) |data| {
        return try parseZon(T, gpa, data);
    } else {
        const info: T = .default;
        const serialized = try serializeZon(arena, info);
        try fs.writeFile(path, serialized);

        return try parseZon(T, gpa, serialized); // an owned instance to free it later
    }
}
