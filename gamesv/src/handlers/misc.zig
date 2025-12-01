const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");
const State = @import("../network/State.zig");
const Memory = State.Memory;
const Assets = @import("../data/Assets.zig");
const PlayerBasicComponent = @import("../logic/component/player/PlayerBasicComponent.zig");

pub fn onGetMiscDataCsReq(
    txn: *network.Transaction(pb.GetMiscDataCsReq),
    mem: Memory,
    assets: *const Assets,
    basic_comp: *PlayerBasicComponent,
) !void {
    errdefer txn.respond(.{ .retcode = 1 }) catch {};
    const templates = &assets.templates;

    var data: pb.MiscData = .{
        .business_card = .{},
        .player_accessory = .{
            .control_guise_avatar_id = basic_comp.info.control_guise_avatar_id,
        },
        .post_girl = .{},
    };

    try data.post_girl.?.post_girl_item_list.append(mem.arena, .{ .id = 3510041 });
    try data.post_girl.?.show_post_girl_id_list.append(mem.arena, 3510041);

    var unlocked_list = try mem.arena.alloc(i32, templates.unlock_config_template_tb.payload.data.len);
    for (templates.unlock_config_template_tb.payload.data, 0..) |template, i| {
        unlocked_list[i] = @intCast(template.id);
    }
    data.unlock = .{ .unlocked_list = .fromOwnedSlice(unlocked_list) };

    var teleport_list = try mem.arena.alloc(i32, templates.teleport_config_template_tb.payload.data.len);
    for (templates.teleport_config_template_tb.payload.data, 0..) |template, i| {
        teleport_list[i] = @intCast(template.teleport_id);
    }
    data.teleport = .{ .unlocked_list = .fromOwnedSlice(teleport_list) };

    try txn.respond(.{ .data = data });
}
