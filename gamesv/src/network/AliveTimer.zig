const AliveTimer = @This();
const std = @import("std");
const Io = std.Io;

const max_alive_duration = Io.Duration.fromSeconds(30);

last_keep_alive: Io.Clock.Timestamp,

pub fn init(io: Io) !AliveTimer {
    return .{
        .last_keep_alive = try .now(io, Io.Clock.real),
    };
}

pub fn reset(timer: *AliveTimer, io: Io) !void {
    timer.last_keep_alive = try .now(io, Io.Clock.real);
}

pub fn wait(timer: *AliveTimer, io: Io) !void {
    const deadline: Io.Timeout = .{
        .deadline = timer.last_keep_alive.addDuration(.{
            .raw = max_alive_duration,
            .clock = Io.Clock.real,
        }),
    };

    try deadline.sleep(io);
}
