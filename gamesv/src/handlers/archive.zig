const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");

pub fn onGetArchiveDataCsReq(txn: *network.Transaction(pb.GetArchiveDataCsReq)) !void {
    try txn.respond(.{
        .retcode = 0,
        .archive_data = .{},
    });
}
