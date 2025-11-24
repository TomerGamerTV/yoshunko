const std = @import("std");
const FileSystem = @import("common").FileSystem;
const Assets = @import("../data/Assets.zig");
const file_util = @import("file_util.zig");

const Allocator = std.mem.Allocator;

pub fn loadAll(
    gpa: Allocator,
    fs: *FileSystem,
    assets: ?*const Assets,
    player_uid: u32,
) !std.AutoArrayHashMapUnmanaged(u32, i32) {
    var map: std.AutoArrayHashMapUnmanaged(u32, i32) = .empty;
    errdefer map.deinit(gpa);

    var temp_allocator = std.heap.ArenaAllocator.init(gpa);
    defer temp_allocator.deinit();
    const arena = temp_allocator.allocator();

    if (try fs.readFile(arena, try std.fmt.allocPrint(arena, "player/{}/materials", .{player_uid}))) |materials| {
        const tuple_list = try file_util.parseZon(struct { []const struct { u32, i32 } }, arena, materials);
        for (tuple_list.@"0") |tuple| {
            const id, const count = tuple;
            try map.put(gpa, id, count);
        }
    } else {
        if (assets) |a| {
            try addDefaults(gpa, a, &map);
            try saveAll(arena, fs, player_uid, &map);
        }
    }

    return map;
}

pub fn saveAll(arena: Allocator, fs: *FileSystem, player_uid: u32, map: *const std.AutoArrayHashMapUnmanaged(u32, i32)) !void {
    const tuple_list = try arena.alloc(struct { u32, i32 }, map.count());
    var iterator = map.iterator();
    var i: usize = 0;
    while (iterator.next()) |kv| : (i += 1) {
        tuple_list[i] = .{ kv.key_ptr.*, kv.value_ptr.* };
    }

    // saving directly as a "[]const struct { u32, i32 }" breaks zon parsing for whatever fucking reason
    const data: struct { []const struct { u32, i32 } } = .{tuple_list};
    const materials = try file_util.serializeZon(arena, data);
    try fs.writeFile(try std.fmt.allocPrint(arena, "player/{}/materials", .{player_uid}), materials);
}

fn addDefaults(gpa: Allocator, assets: *const Assets, map: *std.AutoArrayHashMapUnmanaged(u32, i32)) !void {
    for (assets.templates.avatar_skin_base_template_tb.payload.data) |skin_template| {
        try map.put(gpa, skin_template.id, 1);
    }

    for (assets.templates.avatar_special_awaken_template_tb.payload.data) |awaken_template| {
        for (awaken_template.upgrade_item_ids) |upgrade_item_id| {
            const old_val = try map.getOrPutValue(gpa, upgrade_item_id, 0);
            old_val.value_ptr.* = old_val.value_ptr.* + 1;
        }
    }
}
