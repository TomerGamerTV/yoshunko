const Equip = @This();
const std = @import("std");
const pb = @import("proto").pb;
const Assets = @import("../data/Assets.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const max_property_count: usize = 1;
pub const max_sub_property_count: usize = 4;

pub const data_dir = "equip";
id: u32,
level: u32,
exp: u32,
star: u32,
lock: bool,
properties: [max_property_count]?Property = @splat(null),
sub_properties: [max_sub_property_count]?Property = @splat(null),

pub fn deinit(equip: Equip, gpa: Allocator) void {
    std.zon.parse.free(gpa, equip);
}

pub fn toProto(equip: *const Equip, uid: u32, arena: Allocator) !pb.EquipInfo {
    var equip_info: pb.EquipInfo = .{
        .uid = uid,
        .id = equip.id,
        .level = equip.level,
        .exp = equip.exp,
        .star = equip.star,
        .lock = equip.lock,
    };

    var properties = try std.ArrayList(pb.EquipProperty).initCapacity(arena, max_property_count);
    for (equip.properties) |maybe_property| {
        const property = maybe_property orelse continue;
        properties.appendAssumeCapacity(.{
            .key = property.key,
            .base_value = property.base_value,
            .add_value = property.add_value,
        });
    }

    var sub_properties = try std.ArrayList(pb.EquipProperty).initCapacity(arena, max_sub_property_count);
    for (equip.sub_properties) |maybe_property| {
        const property = maybe_property orelse continue;
        sub_properties.appendAssumeCapacity(.{
            .key = property.key,
            .base_value = property.base_value,
            .add_value = property.add_value,
        });
    }

    equip_info.propertys = properties;
    equip_info.sub_propertys = sub_properties;

    return equip_info;
}

pub const Property = struct {
    key: u32,
    base_value: u32,
    add_value: u32,
};

pub fn addDefaults(gpa: Allocator, assets: *const Assets, map: *std.AutoArrayHashMapUnmanaged(u32, Equip)) !void {
    _ = gpa;
    _ = assets;
    _ = map;
}
