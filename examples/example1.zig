// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const print = std.debug.print;
const cli = @import("zcliconfig");

var config = struct {
    program: [:0]const u8 = undefined,
    help: ?bool = null,
    alpha: ?bool = null,
    beta: ?[:0]const u8 = null,
    gamma: ?bool = null,
    delta: ?bool = null,
    operands: std.ArrayList([:0]u8) = .empty,
    epsilon: ?bool = false,
    dzeta: ?[:0]const u8 = null,
}{};

fn init(_: std.mem.Allocator) void {}

fn deinit(a: std.mem.Allocator) void {
    a.free(config.program);

    for (config.operands.items) |val| {
        a.free(val);
    }

    config.operands.deinit(a);
}

pub fn log(_: *const std.mem.Allocator) !void {
    print("launching {s}\n", .{config.program});
    if (config.alpha) |a| {
        print("-> alpha is {any}\n", .{a});
    }
    if (config.beta) |b| {
        print("-> beta is {s}\n", .{b});
    }
    if (config.gamma) |c| {
        print("-> gamma is {any}\n", .{c});
    }
    if (config.delta) |d| {
        print("-> delta is {any}\n", .{d});
    }
    if (config.epsilon) |e| {
        print("-> epsilon is {any}\n", .{e});
    }
    if (config.dzeta) |dz| {
        print("-> dzeta is {s}\n", .{dz});
    }
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

    const configdesc: cli.Command = .{
        .desc = "ejemplo numero uno",
        .program = &config.program,
        .options = &.{
            .{ .help = "help", .short_name = 'h', .long_name = "help", .ref = cli.ValueRef{ .boolean = &config.help } },
            .{ .help = "first option", .short_name = 'a', .long_name = "alpha", .ref = cli.ValueRef{ .boolean = &config.alpha } },
            .{ .help = "second option", .short_name = 'b', .long_name = "beta", .ref = cli.ValueRef{
                .string = &config.beta,
            }, .mandatory = true },
            .{ .help = "third option", .short_name = 'c', .ref = cli.ValueRef{ .boolean = &config.gamma } },
            .{ .help = 
            \\the fourth option
            \\has a help of
            \\several lines
            , .long_name = "delta", .ref = cli.ValueRef{ .boolean = &config.delta } },
            .{ .help = "fifth option", .long_name = "epsilon", .envvar = "EPSILON", .ref = cli.ValueRef{
                .boolean = &config.epsilon,
            } },
            .{ .help = "sixth option", .long_name = "dzeta", .envvar = "DZETA", .ref = cli.ValueRef{ .string = &config.dzeta } },
        },
        .operands = &config.operands,
        .exec = log,
    };

    try cli.parseCommandLine(allocator, &configdesc, cli.ParserOpts{});

    if (config.help) |_| {
        cli.printHelp(configdesc);
    } else {
        // simulate the program action
        // try log();
    }
}
