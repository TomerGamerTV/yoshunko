const Avatar = @This();
const std = @import("std");
const pb = @import("proto").pb;
const Assets = @import("../data/Assets.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const max_level: u32 = 60;
pub const max_rank: u32 = 6;
pub const max_talent_num: u32 = 6;
pub const max_passive_skill_level: u32 = 6;
pub const equipment_count: u32 = 6;

pub const data_dir: []const u8 = "avatar";
pub const default: Avatar = .{};
level: u32 = max_level,
exp: u32 = 0,
rank: u32 = max_rank,
unlocked_talent_num: u32 = max_talent_num,
talent_switch_list: [max_talent_num]bool = .{ false, false, false, true, true, true },
passive_skill_level: u32 = max_passive_skill_level,
cur_weapon_uid: u32 = 0,
is_favorite: bool = false,
avatar_skin_id: u32 = 0,
is_awake_available: bool = false,
awake_id: u32 = 0,
is_awake_enabled: bool = false,
dressed_equip: [equipment_count]?u32 = @splat(null),
show_weapon_type: ShowWeaponType = .active,
skill_type_level: [SkillLevel.Type.count]SkillLevel = init_skills: {
    var skills: [SkillLevel.Type.count]SkillLevel = undefined;
    for (0..SkillLevel.Type.count) |i| {
        skills[i] = .init(@enumFromInt(i));
    }

    break :init_skills skills;
},

pub fn deinit(avatar: Avatar, gpa: Allocator) void {
    std.zon.parse.free(gpa, avatar);
}

pub fn toProto(avatar: *const Avatar, id: u32, allocator: Allocator) !pb.AvatarInfo {
    var avatar_info: pb.AvatarInfo = .{
        .id = id,
        .level = avatar.level,
        .exp = avatar.exp,
        .rank = avatar.rank,
        .unlocked_talent_num = avatar.unlocked_talent_num,
        .talent_switch_list = .fromOwnedSlice(try allocator.dupe(bool, avatar.talent_switch_list[0..])),
        .passive_skill_level = avatar.passive_skill_level,
        .cur_weapon_uid = avatar.cur_weapon_uid,
        .show_weapon_type = @enumFromInt(@intFromEnum(avatar.show_weapon_type)),
        .is_favorite = avatar.is_favorite,
        .avatar_skin_id = avatar.avatar_skin_id,
        .is_awake_available = avatar.is_awake_available,
        .awake_id = avatar.awake_id,
        .is_awake_enabled = avatar.is_awake_enabled,
    };

    try avatar_info.dressed_equip_list.ensureTotalCapacity(allocator, equipment_count);
    for (avatar.dressed_equip, 1..) |maybe_uid, index| {
        const uid = maybe_uid orelse continue;
        avatar_info.dressed_equip_list.appendAssumeCapacity(.{
            .equip_uid = uid,
            .index = @intCast(index),
        });
    }

    try avatar_info.skill_type_level.ensureTotalCapacity(allocator, avatar.skill_type_level.len);
    for (avatar.skill_type_level) |skill| {
        avatar_info.skill_type_level.appendAssumeCapacity(.{
            .skill_type = @intFromEnum(skill.type),
            .level = skill.level,
        });
    }

    return avatar_info;
}

pub const ShowWeaponType = enum(i32) {
    lock = 0,
    active = 1,
    inactive = 2,
};

pub const SkillLevel = struct {
    type: Type,
    level: u32,

    pub fn init(ty: Type) SkillLevel {
        return .{
            .type = ty,
            .level = ty.getMaxLevel(),
        };
    }

    pub const Type = enum(u32) {
        pub const count: usize = @typeInfo(@This()).@"enum".fields.len;

        common_attack = 0,
        special_attack = 1,
        evade = 2,
        cooperate_skill = 3,
        unique_skill = 4,
        core_skill = 5,
        assist_skill = 6,

        pub fn getMaxLevel(self: @This()) u32 {
            return switch (self) {
                .core_skill => 7,
                else => 12,
            };
        }
    };
};

pub fn addDefaults(gpa: Allocator, assets: *const Assets, map: *std.AutoArrayHashMapUnmanaged(u32, Avatar)) !void {
    for (assets.templates.avatar_base_template_tb.payload.data) |template| {
        if (template.camp != 0) try map.put(gpa, template.id, .default);
    }
}
