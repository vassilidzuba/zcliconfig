// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const opt = @import("./option.zig");
const cmdline = @import("./commandline.zig");

pub const Option = opt.Option;
pub const ValueType = opt.ValueType;
pub const ValueRef = opt.ValueRef;
pub const Parser = cmdline.Parser;

pub fn hello() void {
    std.debug.print("Hello!\n", .{});
}

test "a test" {
    std.debug.print("Hi!\n", .{});
}
