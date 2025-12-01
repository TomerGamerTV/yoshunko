const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");
const State = @import("../network/State.zig");
const Memory = State.Memory;
const PlayerItemComponent = @import("../logic/component/player/PlayerItemComponent.zig");

pub fn onGetItemDataCsReq(
    txn: *network.Transaction(pb.GetItemDataCsReq),
    mem: Memory,
    item_comp: *PlayerItemComponent,
) !void {
    errdefer txn.respond(.{ .retcode = 1 }) catch {};

    var material_list = try mem.arena.alloc(pb.MaterialInfo, item_comp.material_map.count());
    var i: usize = 0;
    var iterator = item_comp.material_map.iterator();

    while (iterator.next()) |kv| : (i += 1) {
        material_list[i] = .{
            .id = kv.key_ptr.*,
            .count = kv.value_ptr.*,
        };
    }

    try txn.respond(.{ .material_list = .fromOwnedSlice(material_list) });
}

pub fn onGetWeaponDataCsReq(
    txn: *network.Transaction(pb.GetWeaponDataCsReq),
    mem: Memory,
    item_comp: *PlayerItemComponent,
) !void {
    errdefer txn.respond(.{ .retcode = 1 }) catch {};

    const weapon_list = try mem.arena.alloc(pb.WeaponInfo, item_comp.weapon_map.count());
    var i: usize = 0;
    var iterator = item_comp.weapon_map.iterator();
    while (iterator.next()) |kv| : (i += 1) {
        weapon_list[i] = try kv.value_ptr.toProto(kv.key_ptr.*, mem.arena);
    }

    try txn.respond(.{ .weapon_list = .fromOwnedSlice(weapon_list) });
}

pub fn onGetEquipDataCsReq(
    txn: *network.Transaction(pb.GetEquipDataCsReq),
    mem: Memory,
    item_comp: *PlayerItemComponent,
) !void {
    errdefer txn.respond(.{ .retcode = 1 }) catch {};

    const equip_list = try mem.arena.alloc(pb.EquipInfo, item_comp.equip_map.count());
    var i: usize = 0;
    var iterator = item_comp.equip_map.iterator();
    while (iterator.next()) |kv| : (i += 1) {
        equip_list[i] = try kv.value_ptr.toProto(kv.key_ptr.*, mem.arena);
    }

    try txn.respond(.{ .equip_list = .fromOwnedSlice(equip_list) });
}

pub fn onGetWishlistDataCsReq(txn: *network.Transaction(pb.GetWishlistDataCsReq)) !void {
    try txn.respond(.{ .retcode = 0 });
}
