const std = @import("std");
const common = @import("common");

const Client = @import("../Client.zig");
const Request = @import("../http/Request.zig");
const Response = @import("../http/Response.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const FileSystem = common.FileSystem;

pub fn process(arena: Allocator, writer: *Io.Writer, fs: *FileSystem, request: Request) !void {
    const log = std.log.scoped(.query_dispatch);

    var maybe_version: ?[]const u8 = null;
    var params = request.params();
    while (params.next()) |param| {
        const name, const value = param;
        if (std.mem.eql(u8, name, "version")) {
            maybe_version = value;
            break;
        }
    }

    const version = maybe_version orelse return;

    if (try fs.readDir("gateway")) |gateway_dir| {
        defer gateway_dir.deinit();
        var region_list: std.ArrayList(ServerListInfo) = .empty;

        for (gateway_dir.entries) |entry| {
            const content = try fs.readFile(arena, entry.path) orelse continue;
            const var_set = try common.var_set.readVarSet(common.Gateway, arena, content) orelse continue;

            const gateway = var_set.data;
            const name = entry.basename();

            for (gateway.versions) |allowed_version| {
                if (std.mem.eql(u8, allowed_version, version)) break;
            } else continue;

            try region_list.append(arena, .{
                .name = name,
                .title = gateway.title,
                .dispatch_url = gateway.dispatch_url,
            });
        }

        if (region_list.items.len != 0) {
            try Response.ok.respondWithJson(writer, .{
                .retcode = 0,
                .region_list = region_list.items,
            });
            return;
        }
    }

    log.warn("no servers found for version '{s}'", .{version});
    try Response.ok.respondWithJson(writer, .{ .retcode = 70 });
}

const ServerList = struct {
    retcode: i32,
    msg: ?[]const u8 = null,
    region_list: []const ServerListInfo = &.{},
};

const ServerListInfo = struct {
    retcode: i32 = 0,
    name: []const u8,
    title: []const u8,
    dispatch_url: []const u8,
    ping_url: []const u8 = "",
    biz: []const u8 = "nap_global",
    area: u8 = 2,
    env: u8 = 2,
    is_recommend: bool = false,
};
