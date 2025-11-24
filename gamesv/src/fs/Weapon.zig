const Weapon = @This();
const std = @import("std");
const pb = @import("proto").pb;
const Assets = @import("../data/Assets.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const data_dir: []const u8 = "weapon";
id: u32,
level: u32,
exp: u32,
star: u32,
refine_level: u32,
lock: bool,

pub fn deinit(weapon: Weapon, gpa: Allocator) void {
    std.zon.parse.free(gpa, weapon);
}

pub fn toProto(weapon: *const Weapon, uid: u32, gpa: Allocator) !pb.WeaponInfo {
    _ = gpa;

    return .{
        .uid = uid,
        .id = weapon.id,
        .level = weapon.level,
        .exp = weapon.exp,
        .star = weapon.star,
        .refine_level = weapon.refine_level,
        .lock = weapon.lock,
    };
}

pub fn addDefaults(gpa: Allocator, assets: *const Assets, map: *std.AutoArrayHashMapUnmanaged(u32, Weapon)) !void {
    for (assets.templates.weapon_template_tb.payload.data, 1..) |weapon_tmpl, uid| {
        const weapon: Weapon = .{
            .id = weapon_tmpl.item_id,
            .level = 60,
            .exp = 0,
            .star = weapon_tmpl.star_limit + 1,
            .refine_level = weapon_tmpl.refine_limit,
            .lock = false,
        };

        try map.put(gpa, @intCast(uid), weapon);
    }
}
