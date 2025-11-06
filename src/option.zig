// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");

pub const ConfigurationDescription = struct {
    program: ?*[:0]const u8 = null,
    options: []const Option,
    operands: *std.ArrayList([:0]u8) = undefined,
};

pub const Option = struct {
    help: []const u8,
    long_name: []const u8 = undefined,
    short_name: u8 = undefined,
    ref: ValueRef,
    hasparams: bool = false,
    params: *std.ArrayList([:0]u8) = undefined,
};

pub const ValueType = enum {
    boolean,
    integer,
    string,
};

pub const ValueRef = union(ValueType) {
    boolean: *bool,
    integer: *i32,
    string: []u8,
};
