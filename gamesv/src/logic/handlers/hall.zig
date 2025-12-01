const std = @import("std");
const Io = std.Io;
const proto = @import("proto");
const pb = proto.pb;
const State = @import("../../network/State.zig");
const Memory = State.Memory;
const Assets = @import("../../data/Assets.zig");
const HallMode = @import("../mode/HallMode.zig");
const EventQueue = @import("../EventQueue.zig");
const PlayerBasicComponent = @import("../component/player/PlayerBasicComponent.zig");
const PlayerHallComponent = @import("../component/player/PlayerHallComponent.zig");
const ModeManager = @import("../mode.zig").ModeManager;
const FileSystem = @import("common").FileSystem;
const Connection = @import("../../network/Connection.zig");

pub fn enterHallSection(
    event: EventQueue.Dequeue(.hall_section_switch),
    mode_mgr: *ModeManager,
    hall_comp: *PlayerHallComponent,
    events: *EventQueue,
    assets: *const Assets,
    fs: *FileSystem,
    mem: Memory,
) !void {
    var mode = try HallMode.init(mem.gpa, fs, assets, hall_comp.player_uid, event.data.section_id);
    if (event.data.transform) |transform| {
        mode.section_info.position.deinit(mem.gpa);
        mode.section_info.position = .{ .born_transform = try mem.gpa.dupe(u8, transform) };
    }

    hall_comp.info.section_id = event.data.section_id;

    mode_mgr.change(mem.gpa, .hall, mode);
    try events.enqueue(.start_event_graph, .{
        .type = .section,
        .event_graph_id = event.data.section_id,
        .entry_event = .on_enter,
    });

    try events.enqueue(.game_mode_transition, .{});
}

pub fn refreshHall(
    _: EventQueue.Dequeue(.hall_refresh),
    basic_comp: *PlayerBasicComponent,
    hall_comp: *PlayerHallComponent,
    mode: *HallMode,
    mem: Memory,
    conn: *Connection,
) !void {
    var notify: pb.HallRefreshScNotify = .{
        .force_refresh = true,
        .section_id = mode.section_id,
        .control_avatar_id = basic_comp.info.control_avatar_id,
        .control_guise_avatar_id = basic_comp.info.control_guise_avatar_id,
        .scene_time_in_minutes = hall_comp.info.time_in_minutes,
        .day_of_week = hall_comp.info.day_of_week,
    };

    const npc_list = try mem.arena.alloc(pb.NpcInfo, mode.npcs.count());
    var npcs = mode.npcs.iterator();
    var i: usize = 0;
    while (npcs.next()) |kv| : (i += 1) {
        npc_list[i] = try kv.value_ptr.toProto(mem.arena, kv.key_ptr.*);
    }

    notify.npc_list = .fromOwnedSlice(npc_list);
    try conn.write(notify, 0);
}
