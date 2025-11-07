// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const print = std.debug.print;
const cli = @import("zcliconfig");

var config = struct {
    program: [:0]const u8 = undefined,
    help: bool = false,
    doalpha: bool = false,
    dobeta: bool = false,
    betaargs: std.ArrayList([:0]u8) = .empty,
    dogamma: bool = false,
    dodelta: bool = false,
    operands: std.ArrayList([:0]u8) = .empty,
    doepsilon: bool = false,
    dodzeta: bool = false,
    dzetaparams: std.ArrayList([:0]u8) = .empty,
}{};

fn init(_: std.mem.Allocator) void {}

fn deinit(a: std.mem.Allocator) void {
    a.free(config.program);
    for (config.betaargs.items) |val| {
        a.free(val);
    }
    config.betaargs.deinit(a);
    for (config.dzetaparams.items) |val| {
        a.free(val);
    }
    config.dzetaparams.deinit(a);

    for (config.operands.items) |val| {
        a.free(val);
    }

    config.operands.deinit(a);
}

pub fn log() !void {
    print("launching {s}\n", .{config.program});
    print("-> alpha is {any}\n", .{config.doalpha});
    print("-> beta is {any}\n", .{config.dobeta});
    for (config.betaargs.items) |x| {
        print("    {s}\n", .{x});
    }
    print("-> gamma is {any}\n", .{config.dogamma});
    print("-> delta is {any}\n", .{config.dodelta});
    print("-> epsilon is {any}\n", .{config.doepsilon});
    print("-> dzeta is {any}\n", .{config.dodzeta});
    for (config.dzetaparams.items) |x| {
        print("    {s}\n", .{x});
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
            .{ .help = "first option", .short_name = 'a', .long_name = "alpha", .ref = cli.ValueRef{ .boolean = &config.doalpha } },
            .{ .help = "second option", .short_name = 'b', .long_name = "beta", .ref = cli.ValueRef{
                .boolean = &config.dobeta,
            }, .hasparams = true, .params = &config.betaargs, .mandatory = true },
            .{ .help = "third option", .short_name = 'c', .ref = cli.ValueRef{ .boolean = &config.dogamma } },
            .{ .help = 
            \\the fourth option
            \\has a help of
            \\several lines
            , .long_name = "delta", .ref = cli.ValueRef{ .boolean = &config.dodelta } },
            .{ .help = "fifth option", .long_name = "epsilon", .envvar = "EPSILON", .ref = cli.ValueRef{
                .boolean = &config.doepsilon,
            } },
            .{ .help = "sixth option", .long_name = "dzeta", .envvar = "DZETA", .params = &config.dzetaparams, .ref = cli.ValueRef{ .boolean = &config.dodzeta } },
        },
        .operands = &config.operands,
        .exec = log,
    };

    try cli.parseCommandLine(allocator, &configdesc, cli.ParserOpts{});

    if (config.help) {
        cli.printHelp(configdesc);
    } else {
        // simulate the program action
        // try log();
    }
}
