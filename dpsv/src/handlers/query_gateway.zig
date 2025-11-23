const std = @import("std");
const common = @import("common");

const Client = @import("../Client.zig");
const Request = @import("../http/Request.zig");
const Response = @import("../http/Response.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const FileSystem = common.FileSystem;

pub fn process(arena: Allocator, writer: *Io.Writer, fs: *FileSystem, request: Request) !void {
    const log = std.log.scoped(.query_gateway);
    errdefer Response.ok.respondWithJson(writer, .{
        .retcode = 70,
    }) catch {};

    var maybe_version: ?[]const u8 = null;
    var maybe_rsa_ver: ?[]const u8 = null;
    var params = request.params();
    while (params.next()) |param| {
        const name, const value = param;
        if (std.mem.eql(u8, name, "version")) {
            maybe_version = value;
        } else if (std.mem.eql(u8, name, "rsa_ver")) {
            maybe_rsa_ver = value;
        }
    }

    const version = maybe_version orelse return error.MissingVersionParameter;
    const rsa_ver = maybe_rsa_ver orelse return error.MissionRsaVerParameter;
    const gateway_name = request.lastPathSegment();

    const gateway_content = try fs.readFile(arena, try std.fmt.allocPrint(arena, "gateway/{s}", .{gateway_name})) orelse {
        log.warn("requested gateway '{s}' doesn't exist", .{gateway_name});
        return error.MissingGatewayRequested;
    };

    const gateway_var_set = try common.var_set.readVarSet(common.Gateway, arena, gateway_content) orelse return error.InvalidGatewayConfig;
    const gateway = gateway_var_set.data;

    const version_content = try fs.readFile(arena, try std.fmt.allocPrint(arena, "version/{s}", .{version})) orelse {
        log.warn("requested version '{s}' doesn't exist", .{version});
        return error.MissingVersionRequested;
    };

    const version_var_set = try common.var_set.readVarSet(common.Version, arena, version_content) orelse return error.InvalidVersionConfig;
    const version_config = version_var_set.data;

    const client_public_key = try fs.readFile(arena, try std.fmt.allocPrint(
        arena,
        "rsa/{s}/client_public_key.der",
        .{rsa_ver},
    )) orelse return error.MissingRsaVersionRequested;

    const server_private_key = try fs.readFile(arena, try std.fmt.allocPrint(
        arena,
        "rsa/{s}/server_private_key.der",
        .{rsa_ver},
    )) orelse return error.MissingRsaVersionRequested;

    const client_secret_key = try fs.readFile(arena, "xorpad/ec2b") orelse blk: {
        log.warn("xorpad/ec2b is not set!", .{});
        break :blk "";
    };

    const data = ServerDispatchData{
        .retcode = 0,
        .title = gateway.title,
        .region_name = gateway_name,
        .gateway = .{
            .ip = gateway.ip,
            .port = gateway.port,
        },
        .client_secret_key = client_secret_key,
        .cdn_check_url = version_config.cdn_check_url,
        .cdn_conf_ext = .{
            .game_res = .{
                .res_revision = version_config.res_revision,
                .audio_revision = version_config.res_revision,
                .base_url = version_config.res_base_url,
                .branch = version_config.branch,
                .md5_files = version_config.res_md5_files,
            },
            .design_data = .{
                .data_revision = version_config.data_revision,
                .base_url = version_config.data_base_url,
                .md5_files = version_config.data_md5_files,
            },
            .silence_data = .{
                .silence_revision = version_config.silence_revision,
                .base_url = version_config.silence_base_url,
                .md5_files = version_config.silence_md5_files,
            },
        },
        .region_ext = .{
            .func_switch = .{
                .isKcp = 0,
                .enableOperationLog = 1,
                .enablePerformanceLog = 1,
            },
        },
    };

    const json_string = try std.fmt.allocPrint(arena, "{f}", .{
        std.json.fmt(&data, .{ .emit_null_optional_fields = false }),
    });

    const content = try arena.alloc(u8, common.rsa.paddedLength(json_string.len));
    var sign: [common.rsa.sign_size]u8 = undefined;

    try common.rsa.encrypt(client_public_key, json_string, content);
    try common.rsa.sign(server_private_key, json_string, &sign);

    Response.ok.respondWithJson(writer, .{
        .content = Base64Fmt{ .data = content },
        .sign = Base64Fmt{ .data = sign[0..] },
    }) catch {};
}

const Base64Fmt = struct {
    data: []const u8,

    pub fn jsonStringify(self: *const @This(), jws: anytype) !void {
        try jws.print("\"{b64}\"", .{self.data});
    }
};

const ServerGateway = struct {
    ip: []const u8,
    port: u16,
};

const CdnGameRes = struct {
    base_url: []const u8,
    res_revision: []const u8,
    audio_revision: []const u8,
    branch: []const u8,
    md5_files: []const u8,
};

const CdnDesignData = struct {
    base_url: []const u8,
    data_revision: []const u8,
    md5_files: []const u8,
};

const CdnSilenceData = struct {
    base_url: []const u8,
    silence_revision: []const u8,
    md5_files: []const u8,
};

const CdnConfExt = struct {
    game_res: CdnGameRes,
    design_data: CdnDesignData,
    silence_data: CdnSilenceData,
};

const RegionSwitchFunc = packed struct {
    enablePerformanceLog: u1,
    enableOperationLog: u1,
    isKcp: u1,
};

const RegionExtension = struct {
    func_switch: RegionSwitchFunc,
};

const ServerDispatchData = struct {
    retcode: i32,
    title: []const u8,
    region_name: []const u8,
    client_secret_key: []const u8,
    cdn_check_url: []const u8,
    gateway: ServerGateway,
    cdn_conf_ext: CdnConfExt,
    region_ext: RegionExtension,
};
