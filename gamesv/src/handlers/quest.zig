const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");

pub fn onGetQuestDataCsReq(context: *network.Context, request: pb.GetQuestDataCsReq) !void {
    try context.respond(pb.GetQuestDataScRsp{
        .quest_type = request.quest_type,
        .quest_data = .{},
    });
}
