const std = @import("std");

const Socket = @import("nekomi").Socket;
const stun = @import("nekomi").stun;

pub fn main() !void {
    const address = try stun.bindAndGetAddr();

    std.debug.print("NAT Mapped Address: {}\n", .{address});

    const server_socket = try Socket.init("127.0.0.1", 8899);
    try server_socket.connect();
}
