const State = @This();
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const Connection = @import("Connection.zig");
const FileSystem = @import("common").FileSystem;
const Assets = @import("../data/Assets.zig");
const AliveTimer = @import("AliveTimer.zig");
const PlayerComponentStorage = @import("../fs/PlayerComponentStorage.zig");
const ModeManager = @import("../logic/mode.zig").ModeManager;
const Dungeon = @import("../logic/battle/Dungeon.zig");
const pb = @import("proto").pb;

pub const Memory = struct {
    gpa: Allocator,
    arena: Allocator,
};

io: Io,
fs: *FileSystem,
assets: *const Assets,
conn: *Connection,
gpa: Allocator,
arena: std.heap.ArenaAllocator,
player_uid: u32,
alive_timer: AliveTimer,
player_components: *PlayerComponentStorage,
player_sync_notify: pb.PlayerSyncScNotify = .{},
mode_manager: ModeManager = .{},
dungeon: ?Dungeon = null,

pub fn deinit(state: *State, gpa: Allocator) void {
    state.mode_manager.deinit(gpa);
    if (state.dungeon) |*d| d.deinit(gpa);
}

pub fn extract(state: *State, comptime T: type) !T {
    if (T == Io) return state.io;
    if (T == *FileSystem) return state.fs;
    if (T == *Connection) return state.conn; // for notifies
    if (T == *const Assets) return state.assets;
    if (T == *AliveTimer) return &state.alive_timer;
    if (T == *pb.PlayerSyncScNotify) return &state.player_sync_notify;
    if (T == *?Dungeon) return &state.dungeon;
    if (T == *Dungeon) return if (state.dungeon) |*dungeon| dungeon else error.NotInDungeon;

    if (T == Memory) return .{
        .gpa = state.gpa,
        .arena = state.arena.allocator(),
    };

    if (T == *ModeManager) return &state.mode_manager;

    if (comptime PlayerComponentStorage.hasComponent(T)) return state.player_components.extract(T);
    if (comptime ModeManager.isMode(T)) return state.mode_manager.extract(T);

    @compileError("can't extract value of type: " ++ @typeName(T));
}

pub fn shouldSendPlayerSync(state: *const State) bool {
    inline for (comptime std.meta.fields(pb.PlayerSyncScNotify)) |field| {
        const value = &@field(state.player_sync_notify, field.name);
        switch (@typeInfo(field.type)) {
            .optional => if (value.* != null) return true,
            .pointer => if (value.len != 0) return true,
            .bool => if (value.*) return true,
            else => {},
        }
    }

    return false;
}
