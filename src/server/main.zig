const std = @import("std");
const Thread = std.Thread;

const Socket = @import("nekomi").Socket;
const Server = @import("Server.zig");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();

    var server = try Server.init("127.0.0.1", 8899);
    const server_thread = try Thread.spawn(.{}, Server.run, .{&server});

    server_thread.join();
}
