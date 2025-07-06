const std = @import("std");

const Client = @import("Client.zig");

pub fn main() !void {
    var client = try Client.join();
    try client.startServerReader();

    while (client.running) {
        std.Thread.sleep(1.0 * std.time.ns_per_s);
    }

    try client.leave();
}
