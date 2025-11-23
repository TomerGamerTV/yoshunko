const std = @import("std");
const common = @import("common");
const FileSystem = common.FileSystem;

pub fn increment(fs: *FileSystem, counter_file: []const u8) !u32 {
    var fmt_buf: [64]u8 = undefined;

    var lock = try fs.lockFile(counter_file) orelse return error.NoCounterFile;
    errdefer lock.unlock(null) catch {};

    var tokens = std.mem.tokenizeAny(u8, lock.content, " \r\n");
    const uid = std.fmt.parseInt(u32, tokens.next() orelse return error.InvalidCounterFile, 10) catch return error.InvalidCounterFile;

    try lock.unlock(std.fmt.bufPrint(fmt_buf[0..], "{}\n", .{uid + 1}) catch unreachable);
    return uid;
}
