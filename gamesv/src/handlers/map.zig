const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");
const State = @import("../network/State.zig");
const Memory = State.Memory;
const Assets = @import("../data/Assets.zig");
const EventQueue = @import("../logic/EventQueue.zig");

pub fn onGetAreaMapDataCsReq(
    txn: *network.Transaction(pb.GetAreaMapDataCsReq),
    mem: Memory,
    assets: *const Assets,
) !void {
    errdefer txn.respond(.{ .retcode = 1 }) catch {};

    const map_group_templates = assets.templates.urban_area_map_group_template_tb.payload.data;
    const group = try mem.arena.alloc(pb.AreaGroupInfo, map_group_templates.len);
    for (map_group_templates, 0..) |template, i| {
        group[i] = .{
            .group_id = template.area_group_id,
            .area_progress = 99,
            .is_unlocked = true,
        };
    }

    const map_templates = assets.templates.urban_area_map_template_tb.payload.data;
    const street = try mem.arena.alloc(pb.AreaStreetInfo, map_templates.len);
    for (map_templates, 0..) |template, i| {
        street[i] = .{
            .area_id = template.area_id,
            .area_progress = 99,
            .is_unlocked = true,
            .is_area_pop_show = true,
            .is_urban_area_show = true,
            .is_3d_area_show = true,
        };
    }

    try txn.respond(.{ .data = .{
        .group = .fromOwnedSlice(group),
        .street = .fromOwnedSlice(street),
    } });
}

pub fn onGetNewAreaPortalListCsReq(txn: *network.Transaction(pb.GetNewAreaPortalListCsReq)) !void {
    try txn.respond(.{ .retcode = 0 });
}
