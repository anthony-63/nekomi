const std = @import("std");

const Client = @import("Client.zig");

pub fn main() !void {
    var client = try Client.join();
    try client.startServerReader();

    try client.leave();
}
