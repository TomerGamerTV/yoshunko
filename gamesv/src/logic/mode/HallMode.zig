const HallMode = @This();
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const FileSystem = @import("common").FileSystem;
const Assets = @import("../../data/Assets.zig");
const comp_util = @import("../component/comp_util.zig");
const file_util = @import("../../fs/file_util.zig");
const Hall = @import("../../fs/Hall.zig");

const log = std.log.scoped(.hall);

player_uid: u32,
section_id: u32,
section_info: Hall.Section,
npcs: std.AutoArrayHashMapUnmanaged(u32, Hall.Npc),

pub fn init(gpa: Allocator, fs: *FileSystem, assets: *const Assets, player_uid: u32, section_id: u32) !HallMode {
    const info = try loadSectionInfo(gpa, assets, fs, player_uid, section_id);
    const npcs = try loadNpcs(gpa, fs, player_uid, section_id);

    return .{
        .player_uid = player_uid,
        .section_id = section_id,
        .section_info = info,
        .npcs = npcs,
    };
}

pub fn deinit(mode: *HallMode, gpa: Allocator) void {
    mode.section_info.deinit(gpa);
    comp_util.freeMap(gpa, &mode.npcs);
}

fn loadSectionInfo(gpa: Allocator, assets: *const Assets, fs: *FileSystem, player_uid: u32, id: u32) !Hall.Section {
    var temp_allocator = ArenaAllocator.init(gpa);
    defer temp_allocator.deinit();
    const arena = temp_allocator.allocator();

    const section_path = try sectionPath(arena, player_uid, id);

    if (try fs.readFile(arena, section_path)) |content|
        return try file_util.parseZon(Hall.Section, gpa, content)
    else {
        const section_template = assets.templates.getConfigByKey(
            .section_config_template_tb,
            id,
        ) orelse return error.InvalidSectionID;

        const section = try Hall.Section.createDefault(gpa, section_template);
        try fs.writeFile(section_path, try file_util.serializeZon(arena, section));

        return section;
    }
}

fn loadNpcs(gpa: Allocator, fs: *FileSystem, player_uid: u32, section_id: u32) !std.AutoArrayHashMapUnmanaged(u32, Hall.Npc) {
    var temp_allocator = ArenaAllocator.init(gpa);
    defer temp_allocator.deinit();
    const arena = temp_allocator.allocator();

    var map: std.AutoArrayHashMapUnmanaged(u32, Hall.Npc) = .empty;
    errdefer comp_util.freeMap(gpa, &map);

    const section_dir = try std.fmt.allocPrint(arena, "player/{}/hall/{}", .{ player_uid, section_id });
    if (try fs.readDir(section_dir)) |dir| {
        defer dir.deinit();

        for (dir.entries) |entry| if (entry.kind == .file) {
            const tag_id = std.fmt.parseInt(u32, entry.basename(), 10) catch continue;
            const npc = file_util.loadZon(Hall.Npc, gpa, arena, fs, "player/{}/hall/{}/{}", .{ player_uid, section_id, tag_id }) catch {
                log.err("failed to load NPC with id {} from section {}", .{ tag_id, section_id });
                continue;
            } orelse continue;

            try map.put(gpa, tag_id, npc);
        };
    }

    return map;
}

fn sectionPath(allocator: Allocator, player_uid: u32, section_id: u32) ![]u8 {
    return std.fmt.allocPrint(allocator, "player/{}/hall/{}/info", .{ player_uid, section_id });
}
