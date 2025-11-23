const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

pub fn Parsed(comptime T: type) type {
    return struct {
        data: T,
        arena: ArenaAllocator,

        pub fn deinit(parsed: @This()) void {
            parsed.arena.deinit();
        }
    };
}

pub fn readVarSet(comptime T: type, gpa: Allocator, content: []const u8) !?Parsed(T) {
    var arena = ArenaAllocator.init(gpa);
    errdefer arena.deinit();

    const data = try readVarSetLeaky(T, arena.allocator(), content) orelse return null;

    return .{
        .data = data,
        .arena = arena,
    };
}

pub fn readVarSetLeaky(comptime T: type, arena: Allocator, data: []const u8) !?T {
    const log = std.log.scoped(.varset);
    const Fields = std.meta.FieldEnum(T);

    var result = std.mem.zeroes(T);
    inline for (std.meta.fields(T)) |field| {
        if (comptime std.meta.activeTag(@typeInfo(field.type)) == .optional) {
            @field(result, field.name) = null;
        }
    }

    var set_fields = std.EnumSet(Fields).initEmpty();

    var lines = std.mem.tokenizeScalar(u8, data, '\n');
    while (lines.next()) |line| if (readVar(arena, line)) |variable| {
        if (std.meta.stringToEnum(Fields, variable.name)) |field_tag| {
            switch (field_tag) {
                inline else => |tag| {
                    if (!set_fields.contains(field_tag)) set_fields.toggle(field_tag);

                    const field = comptime std.meta.fieldInfo(T, tag);
                    if (field.type == []const u8) @field(result, @tagName(tag)) = variable.values[0];
                    if (field.type == []const []const u8) @field(result, @tagName(tag)) = variable.values;

                    if (comptime std.meta.activeTag(@typeInfo(field.type)) == .int) {
                        @field(result, @tagName(tag)) = try std.fmt.parseInt(field.type, variable.values[0], 10);
                    }
                },
            }
        }
    };

    var has_missing_fields = false;

    inline for (std.meta.fields(T)) |field| {
        if (comptime std.meta.activeTag(@typeInfo(field.type)) == .optional) continue;
        if (!set_fields.contains(@field(Fields, field.name))) {
            has_missing_fields = true;
            log.err("missing field: '{s}'", .{field.name});
        }
    }

    return if (has_missing_fields) null else result;
}

const Variable = struct {
    name: []const u8,
    values: []const []const u8,
};

fn readVar(arena: Allocator, raw_line: []const u8) ?Variable {
    var line = raw_line;
    if (line.len != 0 and line[line.len - 1] == '\r') line.len -= 1;
    if (line.len == 0) return null;

    var items = std.mem.tokenizeAny(u8, line, "= ");

    const name = items.next() orelse return null;
    var values: std.ArrayList([]const u8) = .empty;

    while (items.next()) |value| values.append(arena, value) catch return null;
    if (values.items.len == 0) {
        values.deinit(arena);
        return null;
    }

    return .{
        .name = name,
        .values = values.toOwnedSlice(arena) catch return null,
    };
}

pub fn writeVarSet(w: *Io.Writer, varset: anytype) !void {
    const T = @TypeOf(varset);
    inline for (std.meta.fields(T)) |field| {
        try writeVar(w, field.name, @field(varset, field.name));
    }
    try w.writeAll("\n");
}

fn writeVar(w: *Io.Writer, name: [:0]const u8, value: anytype) !void {
    const T = @TypeOf(value);
    if (T == []const u8) {
        try w.print("{s} = {s}\n", .{ name, value });
        return;
    } else if (T == []const []const u8) {
        try w.print("{s} =", .{name});
        for (value) |item| try w.print(" {s}", .{item});
        try w.writeAll("\n");
    } else switch (@typeInfo(T)) {
        .int => try w.print("{s} = {}\n", .{ name, value }),
        .optional => if (value) |item| try writeVar(w, name, item),
        else => @compileError("unsupported type in var set: " ++ @typeName(T)),
    }
}
