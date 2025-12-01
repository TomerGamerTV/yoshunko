const std = @import("std");
const Io = std.Io;
const pb = @import("proto").pb;
const Assets = @import("../../data/Assets.zig");
const Memory = @import("../../network/State.zig").Memory;
const EventQueue = @import("../EventQueue.zig");
const PlayerBasicComponent = @import("../component/player/PlayerBasicComponent.zig");
const PlayerAvatarComponent = @import("../component/player/PlayerAvatarComponent.zig");
const PlayerItemComponent = @import("../component/player/PlayerItemComponent.zig");
const PlayerHallComponent = @import("../component/player/PlayerHallComponent.zig");
const PlayerHadalZoneComponent = @import("../component/player/PlayerHadalZoneComponent.zig");
const comp_util = @import("../component/comp_util.zig");
const FileSystem = @import("common").FileSystem;
const HallMode = @import("../mode/HallMode.zig");

pub fn saveBasicInfo(
    _: EventQueue.Dequeue(.basic_info_modified),
    mem: Memory,
    basic_comp: *PlayerBasicComponent,
    fs: *FileSystem,
) !void {
    const path = try std.fmt.allocPrint(mem.arena, "player/{}/info", .{basic_comp.player_uid});
    try comp_util.saveStruct(fs, basic_comp.info, path, mem.arena);
}

pub fn saveAvatarData(
    event: EventQueue.Dequeue(.avatar_data_modified),
    mem: Memory,
    avatar_comp: *PlayerAvatarComponent,
    fs: *FileSystem,
) !void {
    const avatar_id = event.data.avatar_id;
    const avatar = avatar_comp.avatar_map.getPtr(avatar_id) orelse return;
    const path = try std.fmt.allocPrint(mem.arena, "player/{}/avatar/{}", .{ avatar_comp.player_uid, avatar_id });
    try comp_util.saveStruct(fs, avatar, path, mem.arena);
}

pub fn saveMaterials(
    _: EventQueue.Dequeue(.materials_modified),
    mem: Memory,
    item_comp: *PlayerItemComponent,
    fs: *FileSystem,
) !void {
    try PlayerItemComponent.saveMaterials(mem.arena, fs, item_comp.player_uid, &item_comp.material_map);
}

pub fn saveHadalZone(
    _: EventQueue.Dequeue(.hadal_zone_modified),
    mem: Memory,
    hadal_comp: *PlayerHadalZoneComponent,
    fs: *FileSystem,
) !void {
    const path = try std.fmt.allocPrint(mem.arena, "player/{}/hadal_zone/info", .{hadal_comp.player_uid});
    try comp_util.saveStruct(fs, hadal_comp.info, path, mem.arena);
}

pub fn saveNpc(
    event: EventQueue.Dequeue(.npc_modified),
    mode: *HallMode,
    mem: Memory,
    fs: *FileSystem,
) !void {
    const npc = mode.npcs.getPtr(event.data.npc_tag_id) orelse return;
    const path = try std.fmt.allocPrint(
        mem.arena,
        "player/{}/hall/{}/{}",
        .{ mode.player_uid, mode.section_id, event.data.npc_tag_id },
    );

    try comp_util.saveStruct(fs, npc, path, mem.arena);
}

pub fn saveHallComponent(
    _: EventQueue.Dequeue(.hall_section_switch),
    mem: Memory,
    hall_comp: *PlayerHallComponent,
    fs: *FileSystem,
) !void {
    const path = try std.fmt.allocPrint(mem.arena, "player/{}/hall/info", .{hall_comp.player_uid});
    try comp_util.saveStruct(fs, hall_comp.info, path, mem.arena);
}

pub fn saveHallSection(
    _: EventQueue.Dequeue(.hall_position_changed),
    mem: Memory,
    hall: *HallMode,
    fs: *FileSystem,
) !void {
    const path = try std.fmt.allocPrint(mem.arena, "player/{}/hall/{}/info", .{ hall.player_uid, hall.section_id });
    try comp_util.saveStruct(fs, hall.section_info, path, mem.arena);
}
