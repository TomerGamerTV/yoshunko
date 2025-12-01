const BasicInfo = @This();
const std = @import("std");
const pb = @import("proto").pb;
const Allocator = std.mem.Allocator;

pub const default: @This() = .{};
nickname: []const u8 = "ReversedRooms",
level: u32 = 60,
exp: u32 = 0,
avatar_id: u32 = 2011,
control_avatar_id: u32 = 2011,
control_guise_avatar_id: u32 = 1431,

pub fn deinit(info: BasicInfo, gpa: Allocator) void {
    std.zon.parse.free(gpa, info);
}

pub fn toProto(info: BasicInfo, arena: Allocator) !pb.SelfBasicInfo {
    return .{
        .level = info.level,
        .nick_name = try arena.dupe(u8, info.nickname),
        .avatar_id = info.avatar_id,
        .control_avatar_id = info.control_avatar_id,
        .control_guise_avatar_id = info.control_guise_avatar_id,
        .name_change_times = 1, // TODO
    };
}
