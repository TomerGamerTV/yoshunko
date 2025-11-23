const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");

pub fn onGetArchiveDataCsReq(context: *network.Context, _: pb.GetArchiveDataCsReq) !void {
    try context.respond(pb.GetArchiveDataScRsp{
        .archive_data = .{},
    });
}
