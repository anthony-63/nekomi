const net = @import("std").net;

id: []const u8,
addr: net.Address,
last_seen_secs: f64,
