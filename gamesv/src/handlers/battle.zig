const std = @import("std");
const pb = @import("proto").pb;
const network = @import("../network.zig");

pub fn onStartTrainingQuestCsReq(context: *network.Context, request: pb.StartTrainingQuestCsReq) !void {
    var retcode: i32 = 1;
    defer context.respond(pb.StartTrainingQuestScRsp{ .retcode = retcode }) catch {};

    const dungeon_package_info = try makeDungeonPackage(context, request.avatar_id_list);

    try context.notify(pb.EnterSceneScNotify{
        .scene = .{
            .scene_type = 3,
            .scene_id = 19800014,
            .play_type = 290,
            .fight_scene_data = .{
                .scene_reward = .{},
                .scene_perform = .{},
            },
        },
        .dungeon = .{
            .quest_id = 12254000,
            .dungeon_package_info = dungeon_package_info,
        },
    });

    retcode = 0;
}

fn makeDungeonPackage(context: *network.Context, avatar_id_list: []const u32) !pb.DungeonPackageInfo {
    const player = try context.connection.getPlayer();

    var avatar_list = try context.arena.alloc(pb.AvatarInfo, avatar_id_list.len);
    var weapon_list: std.ArrayList(pb.WeaponInfo) = .empty;
    var equip_list: std.ArrayList(pb.EquipInfo) = .empty;

    for (avatar_id_list, 0..) |avatar_id, i| {
        const avatar = player.avatar_map.getPtr(avatar_id) orelse return error.NoSuchAvatar;
        avatar_list[i] = try avatar.toProto(avatar_id, context.arena);

        if (avatar.cur_weapon_uid != 0) {
            if (player.weapon_map.getPtr(avatar.cur_weapon_uid)) |weapon| {
                try weapon_list.append(context.arena, try weapon.toProto(avatar.cur_weapon_uid, context.arena));
            }
        }

        for (avatar.dressed_equip) |maybe_uid| {
            const uid = maybe_uid orelse continue;
            if (player.equip_map.getPtr(uid)) |equip| {
                try equip_list.append(context.arena, try equip.toProto(uid, context.arena));
            }
        }
    }

    return .{
        .avatar_list = avatar_list,
        .weapon_list = weapon_list.items,
        .equip_list = equip_list.items,
    };
}

pub fn onEndBattleCsReq(context: *network.Context, _: pb.EndBattleCsReq) !void {
    try context.respond(pb.EndBattleScRsp{
        .retcode = 0,
        .fight_settle = .{},
    });
}
