const std = @import("std");
const common = @import("common");
const http = @import("http.zig");
const native_os = @import("builtin").os.tag;

const Io = std.Io;
const Allocator = std.mem.Allocator;
const FileSystem = common.FileSystem;

const Args = struct {
    state_dir: []const u8 = "state",
    listen_address: []const u8 = "127.0.0.1:10100",
};

fn init(gpa: Allocator, io: Io) u8 {
    const log = std.log.scoped(.init);
    common.printSplash();

    const cmd_args = std.process.argsAlloc(gpa) catch @panic("early OOM");
    defer std.process.argsFree(gpa, cmd_args);

    const args = common.args.parse(Args, cmd_args[1..]) orelse {
        common.args.printUsage(Args, cmd_args[0]);
        return 1;
    };

    const address = Io.net.IpAddress.parseLiteral(args.listen_address) catch |err| {
        log.err("invalid listen address specified: {t}", .{err});
        return 1;
    };

    var fs = FileSystem.init(gpa, io, args.state_dir) catch |err| {
        log.err("failed to open filesystem at '{s}': {t}", .{ args.state_dir, err });
        return 1;
    };

    defer fs.deinit();

    var server = address.listen(io, .{ .reuse_address = true }) catch |err| {
        log.err("failed to listen at {f}: {t}", .{ address, err });
        if (err == error.AddressInUse) log.err("another instance of this service might be already running", .{});
        return 1;
    };

    defer server.deinit(io);

    log.info("dispatch server is listening at {f}", .{address});

    var client_group: Io.Group = .init;
    defer client_group.cancel(io);

    while (!io.cancelRequested()) {
        const stream = server.accept(io) catch continue;

        const client_args = .{ gpa, io, &fs, stream };
        client_group.concurrent(io, http.onConnect, client_args) catch
            client_group.async(io, http.onConnect, client_args);
    }

    return 0;
}

pub fn main() u8 {
    if (native_os == .windows) @compileError("Here's a nickel, kid. Get yourself a real OS.");

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);

    var threaded = Io.Threaded.init(debug_allocator.allocator());
    defer threaded.deinit();

    return init(debug_allocator.allocator(), threaded.io());
}
