const std = @import("std");

const Socket = @import("nekomi").Socket;
const Server = @import("Server.zig");

pub fn main() !void {
    var server = try Server.init("127.0.0.1", 8899);
    try server.run();

    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
