const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");

pub fn onGetQuestDataCsReq(txn: *network.Transaction(pb.GetQuestDataCsReq)) !void {
    try txn.respond(.{
        .retcode = 0,
        .quest_type = txn.message.quest_type,
        .quest_data = .{},
    });
}
