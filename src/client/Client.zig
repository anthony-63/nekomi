const std = @import("std");
const net = std.net;
const Thread = std.Thread;

const nekomi = @import("nekomi");
const Client = nekomi.Client;
const Socket = nekomi.Socket;
const stun = nekomi.stun;
const uuid = nekomi.uuid;

const Self = @This();

address: net.Address,
id: uuid.UUID,

server: Socket,
peer: Socket,

mu: Thread.Mutex,
clients: std.StringHashMap(Client),

server_reader_thread: Thread,

running: bool,

pub fn join() !Self {
    const address = try stun.bindAndGetAddr();

    const uid = uuid.newV4();

    const server_socket = try Socket.init("127.0.0.1", 8899);
    try server_socket.connect();

    const peer_ip = net.Address.initIp6([16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, 0, 0, 0);
    const peer_socket = try Socket.initNet(peer_ip);
    try peer_socket.connect();

    _ = try server_socket.sendFmt("JOIN {}", .{uid});

    return Self{
        .address = address,
        .id = uid,
        .peer = peer_socket,
        .server = server_socket,

        .mu = Thread.Mutex{},
        .clients = std.StringHashMap(Client).init(std.heap.page_allocator),

        .server_reader_thread = undefined,

        .running = true,
    };
}

fn handleCommand(self: *Self, msg: []const u8) !void {
    _ = self;
    _ = msg;
}

fn serverReaderReturnsError(self: *Self) !void {
    var buffer: [1024]u8 = undefined;

    while (true) {
        const n = try self.server.recv(&buffer);
        const msg = std.mem.trim(u8, buffer[0..n], " ");

        std.debug.print("RECV(SERVER): {s}\n", .{msg});

        try self.handleCommand(msg);
    }
}

fn serverReader(self: *Self) void {
    serverReaderReturnsError(self) catch |err| {
        std.debug.print("SERVER READER ERROR: {}\n", .{err});
        self.running = false;
    };
}

pub fn startServerReader(self: *Self) !void {
    self.server_reader_thread = try Thread.spawn(.{}, serverReader, .{self});
}

pub fn leave(self: Self) !void {
    _ = try self.server.sendFmt("LEAVE {}", .{self.id});
    self.server.close();
    self.peer.close();

    self.server_reader_thread.join();
}
