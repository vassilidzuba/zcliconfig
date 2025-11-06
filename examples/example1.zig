// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const print = std.debug.print;
const cli = @import("zcliconfig");

var config = struct {
    program: [:0]const u8 = undefined,
    doalpha: bool = false,
    dobeta: bool = false,
    betaargs: std.ArrayList([:0]u8) = .empty,
    dogamma: bool = false,
    operands: std.ArrayList([:0]u8) = .empty,
}{};

fn init(_: std.mem.Allocator) void {}

fn deinit(a: std.mem.Allocator) void {
    a.free(config.program);
    for (config.betaargs.items) |val| {
        a.free(val);
    }
    config.betaargs.deinit(a);
    for (config.operands.items) |val| {
        a.free(val);
    }
    config.operands.deinit(a);
}

pub fn log() void {
    print("launching {s}\n", .{config.program});
    print("-> alpha is {any}\n", .{config.doalpha});
    print("-> beta is {any}\n", .{config.dobeta});
    for (config.betaargs.items) |x| {
        print("    {s}\n", .{x});
    }
    print("-> gamma is {any}\n", .{config.dogamma});
    print("operands\n", .{});
    for (config.operands.items) |x| {
        print("    {s}\n", .{x});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    init(allocator);
    defer deinit(allocator);

    const configdesc: cli.ConfigurationDescription = .{
        .program = &config.program,
        .options = &.{
            .{ .help = "first option", .short_name = 'a', .long_name = "alpha", .ref = cli.ValueRef{ .boolean = &config.doalpha } },
            .{ .help = "second option", .short_name = 'b', .long_name = "beta", .ref = cli.ValueRef{
                .boolean = &config.dobeta,
            }, .hasparams = true, .params = &config.betaargs },
            .{ .help = "third option", .short_name = 'c', .ref = cli.ValueRef{ .boolean = &config.dogamma } },
        },
        .operands = &config.operands,
    };

    try cli.Parser.parseCommandLine(allocator, &configdesc, cli.ParserOpts{});

    log();
}
