const std = @import("std");

pub fn hello() void {
    std.debug.print("Hello!\n", .{});
}

test "a test" {
    std.debug.print("Hi!\n", .{});
}
