const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");

pub fn onGetHollowDataCsReq(txn: *network.Transaction(pb.GetHollowDataCsReq)) !void {
    try txn.respond(.{
        .retcode = 0,
        .hollow_data = .{},
    });
}
