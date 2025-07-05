const std = @import("std");
const thread = std.Thread;

const Client = @import("nekomi").Client;
const Socket = @import("nekomi").Socket;

const Self = @This();

mu: thread.Mutex,
clients: std.AutoHashMap([]const u8, Client),
sock: Socket,

pub fn init(address: []const u8, port: u16) !Self {
    const sock = try Socket.init(address, port);
    try sock.bind();

    return Self{
        .clients = std.AutoHashMap([]const u8, Client).init(std.heap.page_allocator),
        .mu = thread.Mutex{},
        .sock = sock,
    };
}

pub fn run(self: *Self) !void {
    var buffer: [1024]u8 = undefined;

    while (true) {
        const n_from = try self.sock.recvFrom(&buffer);
        const n = n_from.len;
        const remote_addr = n_from.addr;

        const msg = std.mem.trim(u8, buffer[0..n], " ");

        std.debug.print("RECV({}): {s}\n", .{ remote_addr, msg });
    }
}
