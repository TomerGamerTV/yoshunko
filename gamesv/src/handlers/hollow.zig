const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");

pub fn onGetHollowDataCsReq(context: *network.Context, _: pb.GetHollowDataCsReq) !void {
    try context.respond(pb.GetHollowDataScRsp{
        .hollow_data = .{},
    });
}
