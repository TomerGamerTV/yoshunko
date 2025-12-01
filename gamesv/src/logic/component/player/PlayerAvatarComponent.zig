const PlayerAvatarComponent = @This();
const std = @import("std");
const comp_util = @import("../comp_util.zig");
const Avatar = @import("../../../fs/Avatar.zig");
const Assets = @import("../../../data/Assets.zig");
const Allocator = std.mem.Allocator;
const FileSystem = @import("common").FileSystem;

player_uid: u32,
avatar_map: std.AutoArrayHashMapUnmanaged(u32, Avatar) = .empty,

pub fn init(gpa: Allocator, fs: *FileSystem, assets: *const Assets, player_uid: u32) !PlayerAvatarComponent {
    return .{
        .player_uid = player_uid,
        .avatar_map = try comp_util.loadItems(Avatar, gpa, fs, assets, player_uid, false),
    };
}

pub fn deinit(comp: *PlayerAvatarComponent, gpa: Allocator) void {
    comp_util.freeMap(gpa, &comp.avatar_map);
}
