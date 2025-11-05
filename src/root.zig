const std = @import("std");
const cmd = @import("./command.zig");
const cmdline = @import("./commandline.zig");

pub const Command = cmd.Command;
pub const ValueType = cmd.ValueType;
pub const ValueRef = cmd.ValueRef;
pub const Parser = cmdline.Parser;

pub fn hello() void {
    std.debug.print("Hello!\n", .{});
}

test "a test" {
    std.debug.print("Hi!\n", .{});
}
