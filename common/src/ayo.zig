// ReversedRooms extensions for std.Io

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub fn ConcurrentSelect(comptime functions: anytype) type {
    return struct {
        pub const init: @This() = .{};

        const ResultType = blk: {
            const field_names = std.meta.fieldNames(@TypeOf(functions));
            var field_values: [field_names.len]usize = undefined;
            for (field_values[0..], 0..) |*v, i| v.* = i;

            break :blk @Enum(usize, .exhaustive, field_names, &field_values);
        };

        const FutureResult = blk: {
            var names = std.meta.fieldNames(@TypeOf(functions));
            var results: [names.len]type = undefined;
            for (names, 0..) |name, i| {
                results[i] = @typeInfo(@TypeOf(@field(functions, name))).@"fn".return_type.?;
            }

            break :blk @Union(.auto, ResultType, names, &results, &@splat(.{}));
        };

        const TypedFuture = struct {
            result_type: ResultType,
            type_erased: *Io.AnyFuture,
        };

        futures: std.MultiArrayList(TypedFuture) = .empty,

        pub fn cancel(select: *@This(), io: Io, gpa: Allocator) void {
            for (select.futures.items(.result_type), select.futures.items(.type_erased)) |result_type, type_erased| {
                switch (result_type) {
                    inline else => |ty| {
                        const Result = @FieldType(FutureResult, @tagName(ty));
                        var future: Io.Future(Result) = .{
                            .result = undefined,
                            .any_future = type_erased,
                        };

                        if (comptime std.meta.activeTag(@typeInfo(Result)) == .error_union) {
                            _ = future.cancel(io) catch {};
                        } else {
                            _ = future.cancel(io);
                        }
                    },
                }
            }

            select.futures.deinit(gpa);
        }

        pub fn concurrent(
            select: *@This(),
            gpa: Allocator,
            io: Io,
            comptime result_type: ResultType,
            comptime function: anytype,
            args: std.meta.ArgsTuple(@TypeOf(function)),
        ) (Allocator.Error || error{ConcurrencyUnavailable})!void {
            const Result = @typeInfo(@TypeOf(function)).@"fn".return_type.?;

            if (@FieldType(FutureResult, @tagName(result_type)) != Result)
                @compileError("tried to schedule a closure of unregistered type");

            const future = try io.concurrent(function, args);

            try select.futures.append(gpa, .{
                .result_type = result_type,
                .type_erased = future.any_future.?,
            });
        }

        pub fn wait(select: *@This(), io: Io) !FutureResult {
            const index = try io.vtable.select(io.userdata, select.futures.items(.type_erased));
            const result_type = select.futures.items(.result_type)[index];
            const type_erased = select.futures.items(.type_erased)[index];
            select.futures.swapRemove(index);

            switch (result_type) {
                inline else => |ty| {
                    const Result = @FieldType(FutureResult, @tagName(ty));
                    var future: Io.Future(Result) = .{
                        .result = undefined,
                        .any_future = type_erased,
                    };

                    return @unionInit(FutureResult, @tagName(ty), future.await(io));
                },
            }
        }
    };
}
