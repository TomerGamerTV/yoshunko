const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");

pub fn onGetItemDataCsReq(context: *network.Context, _: pb.GetItemDataCsReq) !void {
    errdefer context.respond(pb.GetItemDataScRsp{ .retcode = 1 }) catch {};
    const player = try context.connection.getPlayer();

    var material_list = try context.arena.alloc(pb.MaterialInfo, player.material_map.count());
    var i: usize = 0;
    var iterator = player.material_map.iterator();

    while (iterator.next()) |kv| : (i += 1) {
        material_list[i] = .{
            .id = kv.key_ptr.*,
            .count = kv.value_ptr.*,
        };
    }

    try context.respond(pb.GetItemDataScRsp{ .material_list = material_list });
}

pub fn onGetWeaponDataCsReq(context: *network.Context, _: pb.GetWeaponDataCsReq) !void {
    errdefer context.respond(pb.GetWeaponDataScRsp{ .retcode = 1 }) catch {};
    const player = try context.connection.getPlayer();

    const weapon_list = try context.arena.alloc(pb.WeaponInfo, player.weapon_map.count());
    var i: usize = 0;
    var iterator = player.weapon_map.iterator();
    while (iterator.next()) |kv| : (i += 1) {
        weapon_list[i] = try kv.value_ptr.toProto(kv.key_ptr.*, context.arena);
    }

    try context.respond(pb.GetWeaponDataScRsp{
        .retcode = 0,
        .weapon_list = weapon_list,
    });
}

pub fn onGetEquipDataCsReq(context: *network.Context, _: pb.GetEquipDataCsReq) !void {
    errdefer context.respond(pb.GetEquipDataScRsp{ .retcode = 1 }) catch {};
    const player = try context.connection.getPlayer();

    const equip_list = try context.arena.alloc(pb.EquipInfo, player.equip_map.count());
    var i: usize = 0;
    var iterator = player.equip_map.iterator();
    while (iterator.next()) |kv| : (i += 1) {
        equip_list[i] = try kv.value_ptr.toProto(kv.key_ptr.*, context.arena);
    }

    try context.respond(pb.GetEquipDataScRsp{
        .retcode = 0,
        .equip_list = equip_list,
    });
}

pub fn onGetWishlistDataCsReq(context: *network.Context, _: pb.GetWishlistDataCsReq) !void {
    try context.respond(pb.GetWishlistDataScRsp{});
}
