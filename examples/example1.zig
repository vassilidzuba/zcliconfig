const std = @import("std");
const cli = @import("zcliconfig");

pub fn main() !void {
    cli.hello();
    std.debug.print("Bye!\n", .{});
}
