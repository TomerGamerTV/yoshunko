const std = @import("std");
const pb = @import("proto").pb;
const common = @import("common");
const Connection = @import("Connection.zig");
const Account = @import("../fs/Account.zig");

const rsa = common.rsa;
const base64 = std.base64.standard;
const FileSystem = common.FileSystem;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.auth);

pub const AuthResult = struct {
    player_uid: u32,
    rand_key: u64,
};

pub fn playerGetToken(conn: *Connection, arena: Allocator, fs: *FileSystem, request: pb.PlayerGetTokenCsReq) !AuthResult {
    errdefer conn.write(pb.PlayerGetTokenScRsp{ .retcode = 1 }, 0) catch {};

    var response: pb.PlayerGetTokenScRsp = .default;
    const rand_key = try genRandKey(fs, arena, &request, &response);

    log.debug("account_uid: {s}, token: {s}", .{ request.account_uid, request.token });

    const account = Account.loadOrCreate(arena, fs, request.account_uid) catch |err| {
        log.err("failed to load or create data for account with UID '{s}': {t}", .{ request.account_uid, err });
        return error.AccountLoadFailed;
    };

    response.uid = account.player_uid;

    conn.write(response, 0) catch {};

    return .{
        .player_uid = account.player_uid,
        .rand_key = rand_key,
    };
}

fn genRandKey(fs: *FileSystem, arena: Allocator, request: *const pb.PlayerGetTokenCsReq, response: *pb.PlayerGetTokenScRsp) !u64 {
    const client_public_key = try fs.readFile(arena, try std.fmt.allocPrint(
        arena,
        "rsa/{}/client_public_key.der",
        .{request.rsa_ver},
    )) orelse return error.MissingRsaVersionRequested;

    const server_private_key = try fs.readFile(arena, try std.fmt.allocPrint(
        arena,
        "rsa/{}/server_private_key.der",
        .{request.rsa_ver},
    )) orelse return error.MissingRsaVersionRequested;

    var rand_key_buffer: [64]u8 = undefined;
    var decrypt_buffer: [64]u8 = undefined;

    const ciphertext_size = try base64.Decoder.calcSizeForSlice(request.client_rand_key);
    if (ciphertext_size > rand_key_buffer.len) return error.RandKeyCiphertextTooLong;

    try base64.Decoder.decode(&rand_key_buffer, request.client_rand_key);

    const client_rand_key = try rsa.decrypt(server_private_key, &rand_key_buffer, &decrypt_buffer);
    if (client_rand_key.len != 8) return error.InvalidRandKeySize;

    var server_rand_key: [8]u8 = undefined;
    std.crypto.random.bytes(&server_rand_key);

    var server_rand_key_ciphertext: [rsa.paddedLength(server_rand_key.len)]u8 = undefined;
    var sign: [rsa.sign_size]u8 = undefined;

    try rsa.encrypt(client_public_key, &server_rand_key, &server_rand_key_ciphertext);
    try rsa.sign(server_private_key, &server_rand_key, &sign);

    response.server_rand_key = try std.fmt.allocPrint(arena, "{b64}", .{server_rand_key_ciphertext});
    response.sign = try std.fmt.allocPrint(arena, "{b64}", .{sign});

    return std.mem.readInt(u64, client_rand_key[0..8], .little) ^ std.mem.readInt(u64, &server_rand_key, .little);
}
