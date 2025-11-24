const Assets = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const TemplateCollection = @import("TemplateCollection.zig");
pub const EventGraphCollection = @import("EventGraphCollection.zig");

templates: TemplateCollection,
graphs: EventGraphCollection,

pub fn init(gpa: Allocator, io: Io) !Assets {
    var templates = try TemplateCollection.load(gpa, io);
    errdefer templates.deinit();

    var graphs = try EventGraphCollection.load(gpa, io);
    errdefer graphs.deinit(gpa);

    return .{
        .templates = templates,
        .graphs = graphs,
    };
}

pub fn deinit(assets: *Assets, gpa: Allocator) void {
    assets.templates.deinit();
    assets.graphs.deinit(gpa);
}
