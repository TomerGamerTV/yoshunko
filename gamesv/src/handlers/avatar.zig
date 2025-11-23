const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");
const Player = @import("../fs/Player.zig");
const Avatar = @import("../fs/Avatar.zig");
const Allocator = std.mem.Allocator;

pub fn onGetAvatarDataCsReq(context: *network.Context, _: pb.GetAvatarDataCsReq) !void {
    errdefer context.respond(pb.GetAvatarDataScRsp{ .retcode = 1 }) catch {};
    const player = try context.connection.getPlayer();

    const avatar_list = try context.arena.alloc(pb.AvatarInfo, player.avatar_map.count());
    var i: usize = 0;
    var iterator = player.avatar_map.iterator();
    while (iterator.next()) |kv| : (i += 1) {
        avatar_list[i] = try kv.value_ptr.toProto(kv.key_ptr.*, context.arena);
    }

    try context.respond(pb.GetAvatarDataScRsp{
        .retcode = 0,
        .avatar_list = avatar_list,
    });
}

pub fn onAvatarFavoriteCsReq(context: *network.Context, request: pb.AvatarFavoriteCsReq) !void {
    var retcode: i32 = 1;
    defer context.respond(pb.AvatarFavoriteScRsp{ .retcode = retcode }) catch {};
    defer context.connection.flushSync(context.arena) catch {};

    const player = try context.connection.getPlayer();
    const avatar = player.avatar_map.getPtr(request.avatar_id) orelse return error.NoSuchAvatar;
    avatar.is_favorite = request.is_favorite;

    try player.sync.changed_avatars.put(context.gpa, request.avatar_id, {});
    retcode = 0;
}

pub fn onWeaponDressCsReq(context: *network.Context, request: pb.WeaponDressCsReq) !void {
    var retcode: i32 = 1;
    defer context.respond(pb.WeaponDressScRsp{ .retcode = retcode }) catch {};
    defer context.connection.flushSync(context.arena) catch {};

    const player = try context.connection.getPlayer();
    const avatar = player.avatar_map.getPtr(request.avatar_id) orelse return error.NoSuchAvatar;
    if (!player.weapon_map.contains(request.weapon_uid)) return error.NoSuchWeapon;

    // check if some slave already has it on
    var avatars = player.avatar_map.iterator();
    while (avatars.next()) |kv| {
        if (kv.value_ptr.cur_weapon_uid == request.weapon_uid) {
            kv.value_ptr.cur_weapon_uid = 0;
            try player.sync.changed_avatars.put(context.gpa, kv.key_ptr.*, {});
            break;
        }
    }

    avatar.cur_weapon_uid = request.weapon_uid;
    try player.sync.changed_avatars.put(context.gpa, request.avatar_id, {});
    retcode = 0;
}

pub fn onWeaponUnDressCsReq(context: *network.Context, request: pb.WeaponUnDressCsReq) !void {
    var retcode: i32 = 1;
    defer context.respond(pb.WeaponUnDressScRsp{ .retcode = retcode }) catch {};
    defer context.connection.flushSync(context.arena) catch {};

    const player = try context.connection.getPlayer();
    const avatar = player.avatar_map.getPtr(request.avatar_id) orelse return error.NoSuchAvatar;
    avatar.cur_weapon_uid = 0;
    try player.sync.changed_avatars.put(context.gpa, request.avatar_id, {});

    retcode = 0;
}

pub fn onEquipmentDressCsReq(context: *network.Context, request: pb.EquipmentDressCsReq) !void {
    var retcode: i32 = 1;
    defer context.respond(pb.EquipmentDressScRsp{ .retcode = retcode }) catch {};
    defer context.connection.flushSync(context.arena) catch {};

    const player = try context.connection.getPlayer();
    const avatar = player.avatar_map.getPtr(request.avatar_id) orelse return error.NoSuchAvatar;

    try dressEquip(context.gpa, player, avatar, request.dress_index, request.equip_uid);
    try player.sync.changed_avatars.put(context.gpa, request.avatar_id, {});
    retcode = 0;
}

pub fn onEquipmentUnDressCsReq(context: *network.Context, request: pb.EquipmentUnDressCsReq) !void {
    var retcode: i32 = 1;
    defer context.respond(pb.EquipmentUnDressScRsp{ .retcode = retcode }) catch {};
    defer context.connection.flushSync(context.arena) catch {};

    const player = try context.connection.getPlayer();
    const avatar = player.avatar_map.getPtr(request.avatar_id) orelse return error.NoSuchAvatar;

    for (request.undress_index_list) |index| {
        if (index < 1 or index > 6) continue;
        avatar.dressed_equip[index - 1] = null;
    }

    try player.sync.changed_avatars.put(context.gpa, request.avatar_id, {});
    retcode = 0;
}

pub fn onEquipmentSuitDressCsReq(context: *network.Context, request: pb.EquipmentSuitDressCsReq) !void {
    var retcode: i32 = 1;
    defer context.respond(pb.EquipmentSuitDressScRsp{ .retcode = retcode }) catch {};
    defer context.connection.flushSync(context.arena) catch {};

    const player = try context.connection.getPlayer();
    const avatar = player.avatar_map.getPtr(request.avatar_id) orelse return error.NoSuchAvatar;

    for (request.param_list) |param| {
        try dressEquip(context.gpa, player, avatar, param.dress_index, param.equip_uid);
    }

    try player.sync.changed_avatars.put(context.gpa, request.avatar_id, {});
    retcode = 0;
}

fn dressEquip(gpa: Allocator, player: *Player, target_avatar: *Avatar, index: u32, uid: u32) !void {
    if (index < 1 or index > 6) return error.InvalidDressIndex;
    if (!player.equip_map.contains(uid)) return error.NoSuchEquip;

    var avatars = player.avatar_map.iterator();
    while (avatars.next()) |kv| {
        for (kv.value_ptr.dressed_equip[0..]) |*maybe_uid| {
            if (maybe_uid.* == uid) {
                maybe_uid.* = null;
                try player.sync.changed_avatars.put(gpa, kv.key_ptr.*, {});
                break;
            }
        }
    }

    target_avatar.dressed_equip[index - 1] = uid;
}

pub fn onAvatarSkinDressCsReq(context: *network.Context, request: pb.AvatarSkinDressCsReq) !void {
    var retcode: i32 = 1;
    defer context.respond(pb.AvatarSkinDressScRsp{ .retcode = retcode }) catch {};
    defer if (retcode == 0) context.connection.flushSync(context.arena) catch {};

    const player = try context.connection.getPlayer();
    const avatar = player.avatar_map.getPtr(request.avatar_id) orelse return error.NoSuchAvatar;
    if (!player.material_map.contains(request.avatar_skin_id)) return error.SkinNotUnlocked;

    // TODO: check if the skin actually belongs to this avatar

    avatar.avatar_skin_id = request.avatar_skin_id;
    try player.sync.changed_avatars.put(context.gpa, request.avatar_id, {});

    retcode = 0;
}

pub fn onAvatarSkinUnDressCsReq(context: *network.Context, request: pb.AvatarSkinUnDressCsReq) !void {
    var retcode: i32 = 1;
    defer context.respond(pb.AvatarSkinUnDressScRsp{ .retcode = retcode }) catch {};
    defer if (retcode == 0) context.connection.flushSync(context.arena) catch {};

    const player = try context.connection.getPlayer();
    const avatar = player.avatar_map.getPtr(request.avatar_id) orelse return error.NoSuchAvatar;

    avatar.avatar_skin_id = 0;
    try player.sync.changed_avatars.put(context.gpa, request.avatar_id, {});

    retcode = 0;
}
