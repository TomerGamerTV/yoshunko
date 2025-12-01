const std = @import("std");
const Io = std.Io;
const pb = @import("proto").pb;
const network = @import("../network.zig");
const State = @import("../network/State.zig");
const Memory = State.Memory;
const Assets = @import("../data/Assets.zig");
const PlayerHadalZoneComponent = @import("../logic/component/player/PlayerHadalZoneComponent.zig");
const EventQueue = @import("../logic/EventQueue.zig");

pub fn onGetHadalZoneDataCsReq(
    txn: *network.Transaction(pb.GetHadalZoneDataCsReq),
    io: Io,
    mem: Memory,
    assets: *const Assets,
    hadal_comp: *PlayerHadalZoneComponent,
) !void {
    errdefer txn.respond(.{ .retcode = 1 }) catch {};

    const entrance_list = try mem.arena.alloc(pb.HadalEntranceInfo, hadal_comp.info.entrances.len);
    for (hadal_comp.info.entrances, 0..) |entrance, i| {
        const entrance_type = entrance.entranceType();
        entrance_list[i] = .{
            .entrance_type = entrance_type,
            .entrance_id = entrance.id,
            .state = @enumFromInt(3), // :three:
            .cur_zone_record = try hadal_comp.info.buildZoneRecord(
                io,
                mem.arena,
                assets,
                entrance_type,
                entrance.zone_id,
            ),
        };
    }

    try txn.respond(.{ .hadal_entrance_list = .fromOwnedSlice(entrance_list) });
}

pub fn onSetupHadalZoneRoomCsReq(
    txn: *network.Transaction(pb.SetupHadalZoneRoomCsReq),
    mem: Memory,
    events: *EventQueue,
    hadal_comp: *PlayerHadalZoneComponent,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    for (txn.message.layer_setup_list.items) |setup| {
        const room = try hadal_comp.info.getOrCreateSavedRoom(
            mem.gpa,
            txn.message.zone_id,
            setup.layer_index,
        );

        if (setup.layer_item_id != 0) {
            room.layer_item_id = setup.layer_item_id;
        }

        const new_avatar_list = try mem.gpa.dupe(u32, setup.avatar_id_list.items);
        mem.gpa.free(room.avatar_id_list);
        room.avatar_id_list = new_avatar_list;
        room.buddy_id = setup.buddy_id;
    }

    try events.enqueue(.hadal_zone_modified, .{});
    retcode = 0;
}
