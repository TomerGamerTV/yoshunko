const PlayerHadalZoneComponent = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const FileSystem = @import("common").FileSystem;
const HadalZone = @import("../../../fs/HadalZone.zig");
const file_util = @import("../../../fs/file_util.zig");

player_uid: u32,
info: HadalZone,

pub fn init(gpa: Allocator, fs: *FileSystem, player_uid: u32) !PlayerHadalZoneComponent {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    return .{
        .player_uid = player_uid,
        .info = try file_util.loadOrCreateZon(
            HadalZone,
            gpa,
            arena.allocator(),
            fs,
            "player/{}/hadal_zone/info",
            .{player_uid},
        ),
    };
}

pub fn reload(comp: *PlayerHadalZoneComponent, gpa: Allocator, content: []const u8) !void {
    const new_info = file_util.parseZon(HadalZone, gpa, content) catch return;
    std.zon.parse.free(gpa, comp.info);
    comp.info = new_info;
}

pub fn deinit(comp: PlayerHadalZoneComponent, gpa: Allocator) void {
    std.zon.parse.free(gpa, comp.info);
}
