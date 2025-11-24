const Player = @This();
const std = @import("std");
const pb = @import("proto").pb;
const common = @import("common");
const uid = @import("uid.zig");
const file_util = @import("file_util.zig");
const TemplateCollection = @import("../data/TemplateCollection.zig");

const Avatar = @import("Avatar.zig");
const Weapon = @import("Weapon.zig");
const Equip = @import("Equip.zig");
const Material = @import("Material.zig");
const Hall = @import("Hall.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const FileSystem = common.FileSystem;
const log = std.log.scoped(.player);

pub const BasicInfo = struct {
    pub const default: @This() = .{};
    nickname: []const u8 = "ReversedRooms",
    level: u32 = 60,
    exp: u32 = 0,
    avatar_id: u32 = 2011,
    control_avatar_id: u32 = 2011,
    control_guise_avatar_id: u32 = 1431,

    pub fn deinit(info: BasicInfo, gpa: Allocator) void {
        std.zon.parse.free(gpa, info);
    }
};

pub const item_containers = .{
    .{ Avatar, .avatar_map },
    .{ Weapon, .weapon_map },
    .{ Equip, .equip_map },
};

sync: Sync = .{},
player_uid: u32,
basic_info: BasicInfo,
avatar_map: std.AutoArrayHashMapUnmanaged(u32, Avatar),
weapon_map: std.AutoArrayHashMapUnmanaged(u32, Weapon),
equip_map: std.AutoArrayHashMapUnmanaged(u32, Equip),
material_map: std.AutoArrayHashMapUnmanaged(u32, i32),
hall: Hall,
cur_section: ?Hall.Section = null,

pub const Sync = struct {
    fn HashSet(comptime T: type) type {
        return std.AutoHashMapUnmanaged(T, void);
    }

    pub const change_sets = .{
        .{ Avatar, .changed_avatars },
        .{ Weapon, .changed_weapons },
        .{ Equip, .changed_equips },
    };

    basic_info_changed: bool = false,
    changed_avatars: HashSet(u32) = .empty,
    new_avatars: HashSet(u32) = .empty,
    changed_weapons: HashSet(u32) = .empty,
    changed_equips: HashSet(u32) = .empty,
    materials_changed: bool = false,
    in_scene_transition: bool = false,
    pending_section_switch: ?u32 = null,
    hall_refresh: bool = false,

    pub fn reset(sync: *Sync) void {
        sync.basic_info_changed = false;
        sync.changed_avatars.clearRetainingCapacity();
        sync.new_avatars.clearRetainingCapacity();
        sync.changed_weapons.clearRetainingCapacity();
        sync.changed_equips.clearRetainingCapacity();
        sync.materials_changed = false;
        sync.in_scene_transition = false;
        sync.pending_section_switch = null;
        sync.hall_refresh = false;
    }

    pub fn setChanges(sync: *Sync, comptime T: type, gpa: Allocator, unique_id: u32) !void {
        inline for (Sync.change_sets) |chg| {
            const Type, const set_field = chg;
            if (T == Type) {
                try @field(sync, @tagName(set_field)).put(gpa, unique_id, {});
                break;
            }
        }
    }
};

pub fn save(player: *const Player, arena: Allocator, fs: *FileSystem) !void {
    if (player.sync.basic_info_changed) {
        const basic_info_zon = try file_util.serializeZon(arena, player.basic_info);
        const save_path = try std.fmt.allocPrint(arena, "player/{}/info", .{player.player_uid});
        try fs.writeFile(save_path, basic_info_zon);
    }

    inline for (Player.item_containers, Sync.change_sets) |pair, chg| {
        const Type, const container_field = pair;
        _, const set_field = chg;
        if (chg.@"0" != Type) @compileError("Player.item_containers and Player.Sync.change_sets are out of order!");

        const change_set = &@field(player.sync, @tagName(set_field));
        if (change_set.count() != 0) {
            var ids = change_set.keyIterator();
            while (ids.next()) |id| {
                const item = @field(player, @tagName(container_field)).get(id.*) orelse continue;
                const item_zon = try file_util.serializeZon(arena, item);
                const save_path = try std.fmt.allocPrint(
                    arena,
                    "player/{}/{s}/{}",
                    .{ player.player_uid, Type.data_dir, id.* },
                );
                try fs.writeFile(save_path, item_zon);
            }
        }
    }

    if (player.sync.materials_changed) {
        try Material.saveAll(arena, fs, player.player_uid, &player.material_map);
    }
}

pub fn reloadFile(
    player: *Player,
    gpa: Allocator,
    arena: Allocator,
    fs: *FileSystem,
    file: FileSystem.Changes.File,
    base_dir: []const u8,
) !void {
    const content = try fs.readFile(arena, file.path) orelse return;
    const path = file.path[base_dir.len..];

    inline for (Player.item_containers) |pair| {
        const Type, const container_field = pair;

        if (std.mem.startsWith(u8, path, Type.data_dir ++ "/")) {
            const unique_id = std.fmt.parseInt(u32, file.basename(), 10) catch return;
            const new_value = try file_util.parseZon(Type, gpa, content);
            errdefer new_value.deinit(gpa);

            try player.sync.setChanges(Type, gpa, unique_id);

            const container = &@field(player, @tagName(container_field));
            if (container.getPtr(unique_id)) |ptr| {
                ptr.*.deinit(gpa);
                ptr.* = new_value;
            } else {
                try container.put(gpa, unique_id, new_value);

                if (Type == Avatar) try player.sync.new_avatars.put(gpa, unique_id, {});
            }

            break;
        }
    } else if (std.mem.eql(u8, path, "info")) {
        const new_basic_info = file_util.parseZon(BasicInfo, gpa, content) catch return;
        player.basic_info.deinit(gpa);
        player.basic_info = new_basic_info;
        player.sync.basic_info_changed = true;
    } else if (std.mem.eql(u8, path, "materials")) {
        const new_materials = try Material.loadAll(gpa, fs, null, player.player_uid);
        player.material_map.deinit(gpa);
        player.material_map = new_materials;
        player.sync.materials_changed = true;
    } else if (std.mem.eql(u8, path, "hall/info")) {
        var new_hall = try file_util.parseZon(Hall, gpa, content);

        if (new_hall.section_id != player.hall.section_id) {
            player.sync.pending_section_switch = new_hall.section_id;
            new_hall.section_id = player.hall.section_id;
        } else player.sync.hall_refresh = true;

        player.hall.deinit(gpa);
        player.hall = new_hall;
    }
}

pub fn loadOrCreate(gpa: Allocator, fs: *FileSystem, tmpl: *const TemplateCollection, player_uid: u32) !Player {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const basic_info = try file_util.loadOrCreateZon(BasicInfo, gpa, arena.allocator(), fs, "player/{}/info", .{player_uid});
    const avatar_map = try loadItems(Avatar, gpa, fs, tmpl, player_uid, false);
    const weapon_map = try loadItems(Weapon, gpa, fs, tmpl, player_uid, true);
    const equip_map = try loadItems(Equip, gpa, fs, tmpl, player_uid, true);
    const material_map = try Material.loadAll(gpa, fs, tmpl, player_uid);
    const hall = try file_util.loadOrCreateZon(Hall, gpa, arena.allocator(), fs, "player/{}/hall/info", .{player_uid});

    return .{
        .player_uid = player_uid,
        .basic_info = basic_info,
        .avatar_map = avatar_map,
        .weapon_map = weapon_map,
        .equip_map = equip_map,
        .material_map = material_map,
        .hall = hall,
    };
}

pub fn performHallTransition(player: *Player, gpa: Allocator, fs: *FileSystem, tmpl: *const TemplateCollection) !void {
    var temp_allocator = std.heap.ArenaAllocator.init(gpa);
    defer temp_allocator.deinit();
    const arena = temp_allocator.allocator();

    const section_path = try std.fmt.allocPrint(arena, "player/{}/hall/{}/info", .{ player.player_uid, player.hall.section_id });
    const section = if (try fs.readFile(arena, section_path)) |content|
        try file_util.parseZon(Hall.Section, gpa, content)
    else blk: {
        const section_template = tmpl.getConfigByKey(
            .section_config_template_tb,
            player.hall.section_id,
        ) orelse return error.InvalidSectionID;

        const section = try Hall.Section.createDefault(gpa, section_template);
        try fs.writeFile(section_path, try file_util.serializeZon(arena, section));
        break :blk section;
    };

    if (player.cur_section) |prev_section| prev_section.deinit(gpa);

    player.cur_section = section;
    player.sync.in_scene_transition = true;
}

fn loadItems(
    comptime Item: type,
    gpa: Allocator,
    fs: *FileSystem,
    tmpl: *const TemplateCollection,
    player_uid: u32,
    comptime uses_incr_uid: bool,
) !std.AutoArrayHashMapUnmanaged(u32, Item) {
    var map: std.AutoArrayHashMapUnmanaged(u32, Item) = .empty;
    errdefer map.deinit(gpa);

    var temp_allocator = std.heap.ArenaAllocator.init(gpa);
    defer temp_allocator.deinit();
    const arena = temp_allocator.allocator();

    const data_dir_path = try std.fmt.allocPrint(arena, "player/{}/{s}", .{ player_uid, Item.data_dir });
    if (try fs.readDir(data_dir_path)) |dir| {
        defer dir.deinit();

        for (dir.entries) |entry| if (entry.kind == .file) {
            const unique_id = std.fmt.parseInt(u32, entry.basename(), 10) catch continue;
            const item = file_util.loadZon(Item, gpa, arena, fs, "player/{}/{s}/{}", .{ player_uid, Item.data_dir, unique_id }) catch {
                log.err("failed to load {s} with id {}", .{ @typeName(Item), unique_id });
                continue;
            } orelse continue;

            try map.put(gpa, unique_id, item);
        };
    } else {
        try Item.addDefaults(gpa, tmpl, &map);

        var iterator = map.iterator();
        var highest_uid: u32 = 0;
        while (iterator.next()) |kv| {
            highest_uid = @max(kv.key_ptr.*, highest_uid);

            try fs.writeFile(
                try std.fmt.allocPrint(arena, "player/{}/{s}/{}", .{ player_uid, Item.data_dir, kv.key_ptr.* }),
                try file_util.serializeZon(arena, kv.value_ptr.*),
            );
        }

        if (uses_incr_uid) {
            const counter_path = try std.fmt.allocPrint(arena, "player/{}/{s}/next", .{ player_uid, Item.data_dir });

            var print_buf: [32]u8 = undefined;
            try fs.writeFile(counter_path, try std.fmt.bufPrint(print_buf[0..], "{}", .{highest_uid + 1}));
        }
    }

    return map;
}

pub fn deinit(player: *Player, gpa: Allocator) void {
    player.basic_info.deinit(gpa);
    freeMap(gpa, &player.avatar_map);
    freeMap(gpa, &player.weapon_map);
    freeMap(gpa, &player.equip_map);
    player.material_map.deinit(gpa);
}

fn freeMap(gpa: Allocator, map: anytype) void {
    var iterator = map.iterator();
    while (iterator.next()) |kv| {
        kv.value_ptr.deinit(gpa);
    }

    map.deinit(gpa);
}

pub fn buildBasicInfoProto(player: *const Player, arena: Allocator) !pb.SelfBasicInfo {
    return .{
        .level = player.basic_info.level,
        .nick_name = try arena.dupe(u8, player.basic_info.nickname),
        .avatar_id = player.basic_info.avatar_id,
        .control_avatar_id = player.basic_info.control_avatar_id,
        .control_guise_avatar_id = player.basic_info.control_guise_avatar_id,
        .name_change_times = 1, // TODO
    };
}
