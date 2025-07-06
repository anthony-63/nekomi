const std = @import("std");
const net = std.net;
const Thread = std.Thread;

const Client = @import("nekomi").Client;
const Socket = @import("nekomi").Socket;

const Self = @This();

mu: Thread.Mutex,
clients: std.StringHashMap(Client),
sock: Socket,

pub fn init(address: []const u8, port: u16) !Self {
    const sock = try Socket.init(address, port);
    try sock.bind();

    return Self{
        .clients = std.StringHashMap(Client).init(std.heap.page_allocator),
        .mu = Thread.Mutex{},
        .sock = sock,
    };
}

fn handleCommand(self: *Self, msg: []const u8) !void {
    var parts = std.mem.splitAny(u8, msg, " ");
    const cmd = parts.first();

    if (std.mem.eql(u8, cmd, "JOIN")) {
        const client_id = parts.next().?;
        const ip = parts.next().?;
        const port = try std.fmt.parseInt(u16, parts.next().?, 10);

        self.mu.lock();

        const remote_addr = try net.Address.resolveIp(ip, port);

        const duped_id = try std.heap.page_allocator.dupe(u8, client_id);

        try self.clients.put(duped_id, Client{
            .id = duped_id,
            .addr = remote_addr,
            .last_seen_secs = 0.0,
        });

        var clients_iter = self.clients.iterator();
        while (clients_iter.next()) |c| {
            if (!std.mem.eql(u8, c.key_ptr.*, client_id)) {
                const client = c.value_ptr.*;
                {
                    var addr_iter = std.mem.splitAny(u8, try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{client.addr}), ":");

                    std.debug.print("SEND({}): NEW {s} {s} {s}\n", .{
                        remote_addr,
                        client.id,
                        addr_iter.first(),
                        addr_iter.next().?,
                    });

                    addr_iter.reset();

                    _ = try Socket.writeFmtToAddress(remote_addr, "NEW {s} {s} {s}", .{
                        client.id,
                        addr_iter.first(),
                        addr_iter.next().?,
                    });
                }

                std.debug.print("\n", .{});

                {
                    var addr_iter = std.mem.splitAny(u8, try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{remote_addr}), ":");

                    std.debug.print("SEND({}): NEW {s} {s} {s}\n", .{
                        client.addr,
                        client_id,
                        addr_iter.first(),
                        addr_iter.next().?,
                    });

                    addr_iter.reset();

                    _ = try Socket.writeFmtToAddress(client.addr, "NEW {s} {s} {s}", .{
                        client_id,
                        addr_iter.first(),
                        addr_iter.next().?,
                    });
                }
            }
        }

        self.mu.unlock();
    }
}

pub fn run(self: *Self) !void {
    var buffer: [1024]u8 = undefined;

    while (true) {
        const n_from = try self.sock.recvFrom(&buffer);
        const n = n_from.len;
        const remote_addr = n_from.addr;

        const msg = std.mem.trim(u8, buffer[0..n], " ");

        std.debug.print("RECV({}): {s}\n", .{ remote_addr, msg });

        try self.handleCommand(msg);
    }
}
