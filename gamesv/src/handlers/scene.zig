const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");

pub fn onEnterWorldCsReq(context: *network.Context, _: pb.EnterWorldCsReq) !void {
    try context.notify(pb.EnterSceneScNotify{
        .scene = try makeDefaultHallScene(context),
    });

    try context.respond(pb.EnterWorldScRsp{});
}

pub fn onEnterSectionCompleteCsReq(context: *network.Context, _: pb.EnterSectionCompleteCsReq) !void {
    try context.respond(pb.EnterSectionCompleteScRsp{});
}

pub fn onLeaveCurSceneCsReq(context: *network.Context, _: pb.LeaveCurSceneCsReq) !void {
    try context.notify(pb.EnterSceneScNotify{
        .scene = try makeDefaultHallScene(context),
    });

    try context.respond(pb.LeaveCurSceneScRsp{});
}

fn makeDefaultHallScene(context: *network.Context) !pb.SceneData {
    const player = try context.connection.getPlayer();

    return .{
        .scene_type = 1,
        .hall_scene_data = .{
            .section_id = 1,
            .control_avatar_id = player.basic_info.control_avatar_id,
            .control_guise_avatar_id = player.basic_info.control_guise_avatar_id,
            .transform_id = "Street_PlayerPos_Default",
        },
    };
}
