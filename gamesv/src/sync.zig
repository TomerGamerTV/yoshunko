const std = @import("std");
const pb = @import("proto").pb;
const Player = @import("fs/Player.zig");
const Avatar = @import("fs/Avatar.zig");
const Weapon = @import("fs/Weapon.zig");
const Equip = @import("fs/Equip.zig");
const Connection = @import("network.zig").Connection;
const Allocator = std.mem.Allocator;

const player_sync_fields = .{
    .{ Avatar, .{ .avatar, .avatar_list, pb.AvatarInfo } },
    .{ Weapon, .{ .item, .weapon_list, pb.WeaponInfo } },
    .{ Equip, .{ .item, .equip_list, pb.EquipInfo } },
};

pub fn send(connection: *Connection, arena: Allocator) !void {
    const player = connection.getPlayer() catch return;
    var notify: pb.PlayerSyncScNotify = .default;

    if (player.sync.basic_info_changed) {
        notify.self_basic_info = try player.buildBasicInfoProto(arena);
    }

    inline for (Player.item_containers, Player.Sync.change_sets, player_sync_fields) |pair, chg, field| {
        const Type, const container_field = pair;
        _, const set_field = chg;
        _, const notify_fields = field;
        const notify_container, const notify_list, const PbItem = notify_fields;
        if (chg.@"0" != Type or field.@"0" != Type)
            @compileError("Player.item_containers, Player.Sync.change_sets, player_sync_fields are out of order!");

        const change_set = &@field(player.sync, @tagName(set_field));
        if (change_set.count() != 0) blk: {
            var ids = change_set.keyIterator();
            var list = try arena.alloc(PbItem, change_set.count());
            var i: usize = 0;
            while (ids.next()) |id| : (i += 1) {
                const item = @field(player, @tagName(container_field)).get(id.*) orelse break :blk;
                list[i] = try item.toProto(id.*, arena);
            }

            const container = &@field(notify, @tagName(notify_container));
            if (container.* == null) container.* = .default;
            @field(container.*.?, @tagName(notify_list)) = list;
        }
    }

    if (player.sync.materials_changed) {
        var material_list = try arena.alloc(pb.MaterialInfo, player.material_map.count());
        var i: usize = 0;
        var iterator = player.material_map.iterator();

        while (iterator.next()) |kv| : (i += 1) {
            material_list[i] = .{
                .id = kv.key_ptr.*,
                .count = kv.value_ptr.*,
            };
        }
        if (notify.item == null) {
            notify.item = .default;
        }
        notify.item.?.material_list = material_list;
    }

    connection.write(notify, 0) catch {};

    if (player.sync.new_avatars.count() != 0) {
        var ids = player.sync.new_avatars.keyIterator();
        while (ids.next()) |id| {
            connection.write(pb.AddAvatarScNotify{
                .avatar_id = id.*,
                .perform_type = 2,
            }, 0) catch {};
        }
    }
}
