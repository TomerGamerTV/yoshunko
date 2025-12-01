const PlayerBasicComponent = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const FileSystem = @import("common").FileSystem;
const BasicInfo = @import("../../../fs/BasicInfo.zig");
const file_util = @import("../../../fs/file_util.zig");

player_uid: u32,
info: BasicInfo,

pub fn init(gpa: Allocator, fs: *FileSystem, player_uid: u32) !PlayerBasicComponent {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    return .{
        .player_uid = player_uid,
        .info = try file_util.loadOrCreateZon(
            BasicInfo,
            gpa,
            arena.allocator(),
            fs,
            "player/{}/info",
            .{player_uid},
        ),
    };
}

pub fn reload(comp: *PlayerBasicComponent, gpa: Allocator, content: []const u8) !void {
    const new_basic_info = file_util.parseZon(BasicInfo, gpa, content) catch return;
    std.zon.parse.free(gpa, comp.info);
    comp.info = new_basic_info;
}

pub fn deinit(comp: PlayerBasicComponent, gpa: Allocator) void {
    std.zon.parse.free(gpa, comp.info);
}
