const std = @import("std");
const HallMode = @import("mode/HallMode.zig");
const HollowMode = @import("mode/HollowMode.zig");
const Allocator = std.mem.Allocator;

pub const ModeManager = struct {
    mode: ?GameMode = null,

    pub fn extract(manager: *ModeManager, comptime Mode: type) !Mode {
        if (manager.mode) |*cur_mode| {
            return cur_mode.expect(Mode) orelse return error.InvalidMode;
        } else return error.InvalidMode;
    }

    pub fn change(
        manager: *ModeManager,
        gpa: Allocator,
        comptime t: std.meta.Tag(GameMode),
        mode: @FieldType(GameMode, @tagName(t)),
    ) void {
        if (manager.mode) |*m| m.deinit(gpa);

        manager.mode = @unionInit(GameMode, @tagName(t), mode);
    }

    pub fn isMode(comptime ModePtr: type) bool {
        if (comptime std.meta.activeTag(@typeInfo(ModePtr)) != .pointer) return null;

        const Mode = comptime std.meta.Child(ModePtr);
        return Mode == HallMode or Mode == HollowMode;
    }

    pub fn deinit(manager: *ModeManager, gpa: Allocator) void {
        if (manager.mode) |*mode| mode.deinit(gpa);
    }
};

pub const GameMode = union(enum) {
    hall: HallMode,
    hollow: HollowMode,

    pub fn expect(mode: *GameMode, comptime Mode: type) ?Mode {
        switch (mode.*) {
            inline else => |*m| if (@TypeOf(m) == Mode) return m else return null,
        }
    }

    pub fn deinit(mode: *GameMode, gpa: Allocator) void {
        switch (mode.*) {
            inline else => |*m| m.deinit(gpa),
        }
    }
};
