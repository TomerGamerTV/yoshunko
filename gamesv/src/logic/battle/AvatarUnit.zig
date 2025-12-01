const AvatarUnit = @This();
const std = @import("std");
const property_util = @import("../property_util.zig");
const PropertyType = property_util.PropertyType;
const Allocator = std.mem.Allocator;
const pb = @import("proto").pb;

properties: std.AutoArrayHashMapUnmanaged(PropertyType, i32) = .empty,

pub fn deinit(unit: *AvatarUnit, gpa: Allocator) void {
    unit.properties.deinit(gpa);
}

pub fn toProto(unit: *const AvatarUnit, arena: Allocator, id: u32) !pb.AvatarUnitInfo {
    var info: pb.AvatarUnitInfo = .{
        .avatar_id = id,
    };

    var properties = unit.properties.iterator();
    while (properties.next()) |kv| {
        try info.properties.append(arena, .{
            .key = @intFromEnum(kv.key_ptr.*),
            .value = kv.value_ptr.*,
        });
    }

    return info;
}
