const Hall = @This();
const std = @import("std");
const pb = @import("proto").pb;
const templates = @import("../data/templates.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const default_section_id: u32 = 1;

pub const default: @This() = .{};
section_id: u32 = default_section_id,
time_in_minutes: u11 = 360,
day_of_week: u3 = 5,

pub fn deinit(hall: Hall, gpa: Allocator) void {
    std.zon.parse.free(gpa, hall);
}

pub const Transform = struct {
    position: [3]f64,
    rotation: [3]f64,

    pub fn toProto(t: Transform, arena: Allocator) !pb.Transform {
        return .{
            .position = try arena.dupe(f64, t.position[0..]),
            .rotation = try arena.dupe(f64, t.rotation[0..]),
        };
    }
};

pub const Section = struct {
    position: Position,

    pub const Position = union(enum) {
        born_transform: []const u8,
        custom: Transform,
    };

    pub fn createDefault(gpa: Allocator, template: *const templates.SectionConfigTemplate) !@This() {
        return .{ .position = .{
            .born_transform = try gpa.dupe(u8, template.default_transform),
        } };
    }

    pub fn deinit(section: Section, gpa: Allocator) void {
        std.zon.parse.free(gpa, section);
    }
};
