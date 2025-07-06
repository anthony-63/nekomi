const std = @import("std");
const net = std.net;

const Socket = @import("Socket.zig");

const STUN_MAGIC = [4]u8{ 0x21, 0x12, 0xa4, 0x42 };

const STUN_SERVER = "74.125.250.129";
const STUN_PORT = 19302;

const BIND_REQUEST_HEAD = [8]u8{
    0x00, 0x01, // type
    0x00,          0x00, // length
    STUN_MAGIC[0], STUN_MAGIC[1],
    STUN_MAGIC[2], STUN_MAGIC[3],
};

fn bindRequest() ![20]u8 {
    var rng = std.crypto.random;

    var req: [20]u8 = undefined;
    req[0..8].* = BIND_REQUEST_HEAD;
    for (req[8..]) |*n| {
        n.* = rng.uintAtMost(u8, 255);
    }

    return req;
}

pub fn bindAndGetAddr() !net.Address {
    var req = try bindRequest();

    const sock = try Socket.init(STUN_SERVER, STUN_PORT);
    try sock.connect();

    _ = try sock.send(&req);

    var resp: [1024]u8 = undefined;
    _ = try sock.recv(&resp);

    sock.close();

    return try parseStunResponse(&resp, req[8..20]);
}

fn parseStunResponse(resp: []const u8, txID: []const u8) !net.Address {
    if (resp.len < 20) return error.StunReponseShort;

    const typ = std.mem.readInt(u16, resp[0..2], .big);
    if (typ != 0x0101) return error.InvalidStunResponseType;

    const length = std.mem.readInt(u16, resp[2..4], .big);
    const magic = resp[4..8];

    var magic_valid = true;
    for (0.., magic) |i, m| {
        magic_valid = magic_valid and m == STUN_MAGIC[i];
    }

    if (!magic_valid) return error.InvalidStunMagic;

    const attrs = resp[20 .. 20 + length];
    var i: usize = 0;
    while (i < attrs.len) {
        if (i + 4 > attrs.len) break;

        const attr_typ = std.mem.readInt(u16, @as(*const [2]u8, @ptrCast(attrs[i .. i + 2].ptr)), .big);
        const attr_length = std.mem.readInt(u16, @as(*const [2]u8, @ptrCast(attrs[i + 2 .. i + 4].ptr)), .big);

        if (i + 4 + attr_length > attrs.len) break;

        const val = attrs[i + 4 .. i + 4 + attr_length];

        if (attr_typ == 0x0020) {
            return parseXORMappedAddress(val, magic, txID);
        }

        const padded = (attr_length + 3) & ~@as(u32, 3);
        i += 4 + padded;
    }

    return error.NoXORMappedAddress;
}

fn parseXORMappedAddress(attr: []const u8, magic: []const u8, txID: []const u8) !net.Address {
    if (attr.len < 4) return error.InvalidXORMappedAddresLength;

    const magic_num = std.mem.readInt(u32, @as(*const [4]u8, @ptrCast(magic[0..].ptr)), .big);

    const family = attr[1];
    const port = std.mem.readInt(u16, @as(*const [2]u8, @ptrCast(attr[2..4].ptr)), .big) ^ @as(u16, @intCast(magic_num >> 16));

    var ip: net.Address = undefined;

    switch (family) {
        0x01 => {
            if (attr.len < 8) return error.InvalidIPv4AddressLength;

            ip = net.Address.initIp4([4]u8{
                attr[4] ^ magic[3],
                attr[5] ^ magic[2],
                attr[6] ^ magic[1],
                attr[7] ^ magic[0],
            }, port);
        },
        0x02 => {
            if (attr.len < 20 or txID.len != 12)
                return error.InvalidIPv6AddressLength;

            var xor_key: [16]u8 = undefined;
            for (0.., magic) |i, m| xor_key[i] = m;
            for (0.., txID) |i, t| xor_key[i + 4] = t;

            var addr: [16]u8 = undefined;
            for (0..16) |i| addr[i] = attr[i + 4] ^ xor_key[i];

            ip = net.Address.initIp6(addr, port, 0, 0);
        },
        else => return error.UnkownAddressFamily,
    }

    return ip;
}
