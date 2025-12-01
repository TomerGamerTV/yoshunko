const PlayerHallComponent = @This();
const std = @import("std");
const comp_util = @import("../comp_util.zig");
const file_util = @import("../../../fs/file_util.zig");
const Assets = @import("../../../data/Assets.zig");
const Hall = @import("../../../fs/Hall.zig");
const Allocator = std.mem.Allocator;
const FileSystem = @import("common").FileSystem;

player_uid: u32,
info: Hall,

pub fn init(gpa: Allocator, fs: *FileSystem, player_uid: u32) !PlayerHallComponent {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    return .{
        .player_uid = player_uid,
        .info = try file_util.loadOrCreateZon(Hall, gpa, arena.allocator(), fs, "player/{}/hall/info", .{player_uid}),
    };
}

pub fn deinit(comp: *PlayerHallComponent, gpa: Allocator) void {
    comp.info.deinit(gpa);
}
