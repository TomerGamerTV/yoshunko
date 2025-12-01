const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");
const State = @import("../network/State.zig");
const Avatar = @import("../fs/Avatar.zig");
const Memory = State.Memory;
const EventQueue = @import("../logic/EventQueue.zig");
const PlayerAvatarComponent = @import("../logic/component/player/PlayerAvatarComponent.zig");
const PlayerItemComponent = @import("../logic/component/player/PlayerItemComponent.zig");
const Assets = @import("../data/Assets.zig");

pub fn onGetAvatarDataCsReq(
    txn: *network.Transaction(pb.GetAvatarDataCsReq),
    mem: Memory,
    avatar_comp: *PlayerAvatarComponent,
) !void {
    errdefer txn.respond(.{ .retcode = 1 }) catch {};

    const avatar_list = try mem.arena.alloc(pb.AvatarInfo, avatar_comp.avatar_map.count());
    var i: usize = 0;
    var iterator = avatar_comp.avatar_map.iterator();
    while (iterator.next()) |kv| : (i += 1) {
        avatar_list[i] = try kv.value_ptr.toProto(kv.key_ptr.*, mem.arena);
    }

    try txn.respond(.{
        .retcode = 0,
        .avatar_list = .fromOwnedSlice(avatar_list),
    });
}

pub fn onAvatarFavoriteCsReq(
    txn: *network.Transaction(pb.AvatarFavoriteCsReq),
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    const avatar = avatar_comp.avatar_map.getPtr(txn.message.avatar_id) orelse return error.NoSuchAvatar;
    avatar.is_favorite = txn.message.is_favorite;

    try events.enqueue(.avatar_data_modified, .{ .avatar_id = txn.message.avatar_id });
    retcode = 0;
}

pub fn onWeaponDressCsReq(
    txn: *network.Transaction(pb.WeaponDressCsReq),
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
    item_comp: *PlayerItemComponent,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    const avatar = avatar_comp.avatar_map.getPtr(txn.message.avatar_id) orelse return error.NoSuchAvatar;
    if (!item_comp.weapon_map.contains(txn.message.weapon_uid)) return error.NoSuchWeapon;

    // check if some slave already has it on
    var avatars = avatar_comp.avatar_map.iterator();
    while (avatars.next()) |kv| {
        if (kv.value_ptr.cur_weapon_uid == txn.message.weapon_uid) {
            kv.value_ptr.cur_weapon_uid = 0;
            try events.enqueue(.avatar_data_modified, .{ .avatar_id = kv.key_ptr.* });
            break;
        }
    }

    avatar.cur_weapon_uid = txn.message.weapon_uid;
    try events.enqueue(.avatar_data_modified, .{ .avatar_id = txn.message.avatar_id });
    retcode = 0;
}

pub fn onWeaponUnDressCsReq(
    txn: *network.Transaction(pb.WeaponUnDressCsReq),
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    const avatar = avatar_comp.avatar_map.getPtr(txn.message.avatar_id) orelse return error.NoSuchAvatar;
    avatar.cur_weapon_uid = 0;

    try events.enqueue(.avatar_data_modified, .{ .avatar_id = txn.message.avatar_id });
    retcode = 0;
}

pub fn onEquipmentDressCsReq(
    txn: *network.Transaction(pb.EquipmentDressCsReq),
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
    item_comp: *PlayerItemComponent,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    const avatar = avatar_comp.avatar_map.getPtr(txn.message.avatar_id) orelse return error.NoSuchAvatar;

    try dressEquip(events, avatar_comp, item_comp, avatar, txn.message.dress_index, txn.message.equip_uid);
    try events.enqueue(.avatar_data_modified, .{ .avatar_id = txn.message.avatar_id });
    retcode = 0;
}

pub fn onEquipmentUnDressCsReq(
    txn: *network.Transaction(pb.EquipmentUnDressCsReq),
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    const avatar = avatar_comp.avatar_map.getPtr(txn.message.avatar_id) orelse return error.NoSuchAvatar;

    for (txn.message.undress_index_list.items) |index| {
        if (index < 1 or index > 6) continue;
        avatar.dressed_equip[index - 1] = null;
    }

    try events.enqueue(.avatar_data_modified, .{ .avatar_id = txn.message.avatar_id });
    retcode = 0;
}

pub fn onEquipmentSuitDressCsReq(
    txn: *network.Transaction(pb.EquipmentSuitDressCsReq),
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
    item_comp: *PlayerItemComponent,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    const avatar = avatar_comp.avatar_map.getPtr(txn.message.avatar_id) orelse return error.NoSuchAvatar;

    for (txn.message.param_list.items) |param| {
        try dressEquip(events, avatar_comp, item_comp, avatar, param.dress_index, param.equip_uid);
    }

    try events.enqueue(.avatar_data_modified, .{ .avatar_id = txn.message.avatar_id });
    retcode = 0;
}

fn dressEquip(
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
    item_comp: *PlayerItemComponent,
    target_avatar: *Avatar,
    index: u32,
    uid: u32,
) !void {
    if (index < 1 or index > 6) return error.InvalidDressIndex;
    if (!item_comp.equip_map.contains(uid)) return error.NoSuchEquip;

    var avatars = avatar_comp.avatar_map.iterator();
    while (avatars.next()) |kv| {
        for (kv.value_ptr.dressed_equip[0..]) |*maybe_uid| {
            if (maybe_uid.* == uid) {
                maybe_uid.* = null;
                try events.enqueue(.avatar_data_modified, .{ .avatar_id = kv.key_ptr.* });
                break;
            }
        }
    }

    target_avatar.dressed_equip[index - 1] = uid;
}

pub fn onAvatarSkinDressCsReq(
    txn: *network.Transaction(pb.AvatarSkinDressCsReq),
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
    item_comp: *PlayerItemComponent,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    const avatar = avatar_comp.avatar_map.getPtr(txn.message.avatar_id) orelse return error.NoSuchAvatar;
    if (!item_comp.material_map.contains(txn.message.avatar_skin_id)) return error.SkinNotUnlocked;

    // TODO: check if the skin actually belongs to this avatar

    avatar.avatar_skin_id = txn.message.avatar_skin_id;
    try events.enqueue(.avatar_data_modified, .{ .avatar_id = txn.message.avatar_id });

    retcode = 0;
}

pub fn onAvatarSkinUnDressCsReq(
    txn: *network.Transaction(pb.AvatarSkinUnDressCsReq),
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    const avatar = avatar_comp.avatar_map.getPtr(txn.message.avatar_id) orelse return error.NoSuchAvatar;

    avatar.avatar_skin_id = 0;
    try events.enqueue(.avatar_data_modified, .{ .avatar_id = txn.message.avatar_id });

    retcode = 0;
}

pub fn onAvatarUnlockAwakeCsReq(
    txn: *network.Transaction(pb.AvatarUnlockAwakeCsReq),
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
    item_comp: *PlayerItemComponent,
    assets: *const Assets,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    const avatar = avatar_comp.avatar_map.getPtr(txn.message.avatar_id) orelse return error.NoSuchAvatar;

    const config = assets.templates.getAvatarTemplateConfig(txn.message.avatar_id) orelse
        return error.MissingAvatarConfig;

    var awake_id: u32 = 0;
    var i: u8 = 0;
    while (config.special_awaken_templates[i]) |template| : (i += 1) {
        if (template.id > avatar.awake_id) {
            awake_id = template.id;

            for (template.upgrade_item_ids) |upgrade_item_id| {
                const material_count = item_comp.material_map.get(upgrade_item_id) orelse return error.PlayerMissingUpgradeItem;
                if (material_count < 1) {
                    return error.PlayerMissingUpgradeItem;
                }
            }

            for (template.upgrade_item_ids) |upgrade_item_id| {
                const material_ptr = item_comp.material_map.getPtr(upgrade_item_id) orelse return error.PlayerMissingUpgradeItem;
                material_ptr.* = material_ptr.* - 1;
            }

            break;
        }
        if (i == config.special_awaken_templates.len - 1) break;
    }

    if (awake_id == 0) return error.MissingNextAvatarAwake;

    if (avatar.awake_id == 0) {
        avatar.is_awake_available = true;
        avatar.is_awake_enabled = true;
    }

    avatar.awake_id = awake_id;

    try events.enqueue(.materials_modified, .{});
    try events.enqueue(.avatar_data_modified, .{ .avatar_id = txn.message.avatar_id });

    retcode = 0;
}

pub fn onAvatarSetAwakeCsReq(
    txn: *network.Transaction(pb.AvatarSetAwakeCsReq),
    events: *EventQueue,
    avatar_comp: *PlayerAvatarComponent,
) !void {
    var retcode: i32 = 1;
    defer txn.respond(.{ .retcode = retcode }) catch {};

    const avatar = avatar_comp.avatar_map.getPtr(txn.message.avatar_id) orelse return error.NoSuchAvatar;

    if (avatar.awake_id == 0) {
        return error.NoAwakeUnlocked;
    }

    avatar.is_awake_enabled = txn.message.is_awake_enabled;
    try events.enqueue(.avatar_data_modified, .{ .avatar_id = txn.message.avatar_id });

    retcode = 0;
}
