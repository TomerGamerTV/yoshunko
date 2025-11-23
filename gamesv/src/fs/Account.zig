const Account = @This();
const std = @import("std");
const common = @import("common");
const uid = @import("uid.zig");
const file_util = @import("file_util.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const FileSystem = common.FileSystem;

player_uid: u32,

pub fn loadOrCreate(arena: Allocator, fs: *FileSystem, account_uid: []const u8) !Account {
    const log = std.log.scoped(.account_load);

    const account_file_path = try std.fmt.allocPrint(arena, "account/{s}", .{account_uid});
    if (try fs.readFile(arena, account_file_path)) |account_data| {
        const account = file_util.parseZon(Account, arena, account_data) catch {
            log.err("account_uid='{s}': data is corrupted", .{account_uid});
            return error.Corrupted;
        };

        return account;
    } else {
        const player_uid = try uid.increment(fs, "player/next");
        const account: Account = .{ .player_uid = player_uid };

        const data = try file_util.serializeZon(arena, account);
        try fs.writeFile(account_file_path, data);

        return account;
    }
}
