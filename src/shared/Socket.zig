const std = @import("std");
const net = std.net;
const os = std.os;
const posix = std.posix;

const Self = @This();

address: net.Address,
socket: posix.socket_t,

const RecvFromReturn = struct {
    len: usize,
    addr: net.Address,
};

pub fn init(address: []const u8, port: u16) !Self {
    const parsed_address = try net.Address.resolveIp(address, port);
    const sock = try posix.socket(parsed_address.any.family, posix.SOCK.DGRAM, posix.IPPROTO.UDP);

    return Self{
        .address = parsed_address,
        .socket = sock,
    };
}

pub fn initNet(address: net.Address) !Self {
    const sock = try posix.socket(address.any.family, posix.SOCK.DGRAM, posix.IPPROTO.UDP);

    return Self{
        .address = address,
        .socket = sock,
    };
}

pub fn connect(self: Self) !void {
    try posix.connect(self.socket, &self.address.any, self.address.getOsSockLen());
}

pub fn bind(self: Self) !void {
    try posix.bind(self.socket, &self.address.any, self.address.getOsSockLen());
}

pub fn recv(self: Self, buffer: []u8) !usize {
    return try posix.recv(self.socket, buffer[0..], 0);
}

pub fn recvFrom(self: Self, buffer: []u8) !RecvFromReturn {
    var addr: posix.sockaddr = undefined;
    var addr_len: u32 = @intCast(@sizeOf(posix.sockaddr));
    const n = try posix.recvfrom(self.socket, buffer[0..], 0, &addr, &addr_len);
    const address = net.Address.initPosix(@alignCast(&addr));

    return RecvFromReturn{
        .len = n,
        .addr = address,
    };
}

pub fn send(self: Self, data: []u8) !usize {
    return try posix.send(self.socket, data[0..], 0);
}

pub fn sendFmt(self: Self, comptime fmt: []const u8, args: anytype) !usize {
    const str = try std.fmt.allocPrint(std.heap.page_allocator, fmt, args);
    return try self.send(str);
}

pub fn sendTo(self: Self, address: net.Address, data: []const u8) !usize {
    return try posix.sendto(self.socket, data, 0, &address.any, address.getOsSockLen());
}

pub fn sendToFmt(self: Self, address: net.Address, comptime fmt: []const u8, args: anytype) !usize {
    const str = try std.fmt.allocPrint(std.heap.page_allocator, fmt, args);
    return try self.sendTo(address, str);
}

pub fn close(self: Self) void {
    posix.close(self.socket);
}
