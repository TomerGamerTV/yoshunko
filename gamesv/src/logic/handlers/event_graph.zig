const std = @import("std");
const Io = std.Io;
const proto = @import("proto");
const pb = proto.pb;
const State = @import("../../network/State.zig");
const Memory = State.Memory;
const Assets = @import("../../data/Assets.zig");
const Hall = @import("../../fs/Hall.zig");
const HallMode = @import("../mode/HallMode.zig");
const EventQueue = @import("../EventQueue.zig");
const Connection = @import("../../network/Connection.zig");
const PlayerBasicComponent = @import("../component/player/PlayerBasicComponent.zig");
const PlayerHallComponent = @import("../component/player/PlayerHallComponent.zig");

pub fn startHallEvent(
    event: EventQueue.Dequeue(.start_event_graph),
    mode: *HallMode,
    events: *EventQueue,
    assets: *const Assets,
    conn: *Connection, // to send the notify. TODO: move notifying out of this handler.
    mem: Memory,
) !void {
    const log = std.log.scoped(.hall_event);

    const graph = assets.graphs.getEventGraph(event.data.type, event.data.event_graph_id) orelse {
        log.warn("missing event graph of type {t} with id {}", .{ event.data.type, event.data.event_graph_id });
        return;
    };

    const event_group = switch (event.data.entry_event) {
        inline else => |ev| @field(graph, @tagName(ev)),
    };

    for (graph.events) |e| {
        if (std.mem.findScalar(u32, event_group, e.id) != null) {
            for (e.actions) |action| {
                switch (action.action) {
                    .create_npc => |config| {
                        const template = assets.templates.getConfigByKey(.main_city_object_template_tb, config.tag_id) orelse {
                            continue;
                        };

                        var npc: Hall.Npc = .{};

                        if (template.default_interact_ids.len != 0) {
                            npc.interacts[1] = .{
                                .name = try mem.gpa.dupe(u8, template.interact_name),
                                .scale = @splat(1),
                                .tag_id = config.tag_id,
                                .id = template.default_interact_ids[0],
                            };
                        }

                        try mode.npcs.put(mem.gpa, config.tag_id, npc);
                        try events.enqueue(.npc_modified, .{ .npc_tag_id = config.tag_id });
                    },
                    .change_interact => |config| {
                        for (config.tag_ids) |tag_id| {
                            const npc = mode.npcs.getPtr(tag_id) orelse continue;
                            const template = assets.templates.getConfigByKey(.main_city_object_template_tb, tag_id) orelse {
                                continue;
                            };

                            if (npc.interacts[1]) |*interact| interact.deinit(mem.gpa);

                            npc.interacts[1] = .{
                                .name = try mem.gpa.dupe(u8, template.interact_name),
                                .scale = @splat(1),
                                .tag_id = tag_id,
                                .id = config.interact_id,
                                .participators = &.{},
                            };

                            try events.enqueue(.npc_modified, .{ .npc_tag_id = tag_id });
                        }
                    },
                    else => {},
                }

                switch (action.action) {
                    inline else => |config| {
                        if (@hasDecl(@TypeOf(config), "toProto")) {
                            const data = try config.toProto(mem.arena);
                            var allocating = Io.Writer.Allocating.init(mem.arena);
                            try proto.encodeMessage(&allocating.writer, data, proto.pb.desc_action);

                            var notify: pb.SectionEventScNotify = .{ .section_id = mode.section_id };
                            try notify.action_list.append(mem.arena, .{
                                .action_type = @enumFromInt(@intFromEnum(action.action)),
                                .body = allocating.written(),
                            });

                            try conn.write(notify, 0);
                        }
                    },
                }
            }
        }
    }
}
