// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const print = std.debug.print;

/// Description of a Command
pub const Command = struct {
    // subcommand name; not used for root command
    name: [:0]const u8 = "root",
    desc: []const u8 = undefined,
    // reference to the program path;
    // set only for the root command
    program: ?*[:0]const u8 = null,
    // list of option description
    options: []const Option = &.{},
    operands: *std.ArrayList([:0]u8) = undefined,
    subcommands: []const Command = &.{},
    exec: ?*const fn () anyerror!void = null,
};

/// description of a single optioon
pub const Option = struct {
    help: [:0]const u8,
    long_name: ?[]const u8 = null,
    short_name: ?u8 = null,
    ref: ValueRef,
    envvar: ?[]const u8 = null,
    //hasparams: bool = false,
    mandatory: bool = false,
};

pub const ValueType = enum {
    boolean,
    string,
};

// reference to a value.
// That value can be a boolean, an integer or a string
pub const ValueRef = union(ValueType) {
    boolean: *?bool,
    string: *?[:0]const u8,
};

pub fn printHelp(desc: Command) void {
    const lns = getLongNamleMaxWidth(desc);
    print("{s}\n", .{desc.desc});
    for (desc.options) |opt| {
        if (opt.short_name) |short_name| {
            print(" -{c}", .{short_name});
        } else {
            print("   ", .{});
        }
        if (opt.long_name) |long_name| {
            print(" --", .{});
            printString(long_name, lns + 3);
        } else {
            printString("", lns + 6);
        }
        printHelpField(opt.help, lns + 9);
    }
}

fn getLongNamleMaxWidth(desc: Command) usize {
    var size: usize = 0;
    for (desc.options) |opt| {
        if (opt.long_name) |long_name| {
            if (long_name.len > size) {
                size = long_name.len;
            }
        }
    }
    return size;
}

fn printHelpField(s: [:0]const u8, prefixsize: usize) void {
    var it = std.mem.splitScalar(u8, s, '\n');
    var firstline: bool = true;
    while (it.next()) |x| {
        if (!firstline) {
            for (0..prefixsize) |_| {
                print(" ", .{});
            }
        }
        firstline = false;
        print("{s}\n", .{x});
    }
}

fn printString(val: []const u8, size: usize) void {
    print("{s}", .{val});
    if (val.len < size) {
        const padding = size - val.len;
        for (0..padding) |_| {
            print(" ", .{});
        }
    }
}

test "reference to boolean" {
    var val: ?bool = null;
    const ref = ValueRef{ .boolean = &val };
    ref.boolean.* = true;
    try std.testing.expect(val.?);
}

test "reference to string" {
    var val: ?[:0]const u8 = "beta";
    try std.testing.expectEqual(val.?, "beta");
    const ref = ValueRef{ .string = &val };
    ref.string.* = "alpha";
    try std.testing.expectEqual(val.?, "alpha");
}

test "reference to string dynamic" {
    var ta = std.testing.allocator;
    var val: ?[:0]const u8 = "beta";
    try std.testing.expectEqual(val.?, "beta");
    const ref = ValueRef{ .string = &val };
    ref.string.* = try std.mem.Allocator.dupeZ(ta, u8, "alpha");
    try std.testing.expectEqualSlices(u8, val.?, "alpha");
    ta.free(ref.string.*.?);
}
