// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const print = std.debug.print;
const cli = @import("zcliconfig");

fn init(_: std.mem.Allocator) void {}

fn deinit(_: std.mem.Allocator) void {}

var config1 = struct {
    a: ?bool = null,
}{};

var config2 = struct {
    b: ?bool = null,
}{};

var config = struct {
    r: ?bool = null,
}{};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    init(allocator);
    defer deinit(allocator);

    const subcmd1: cli.Command = .{
        .desc = "subcommand 1",
        .name = "cmd1",
        .exec = runSubcmd1,
        .options = &.{
            .{
                .help = "option a",
                .short_name = 'a',
                .long_name = "alpha",
                .ref = cli.ValueRef{ .boolean = &config1.a },
            },
        },
    };

    const subcmd2: cli.Command = .{
        .desc = "subcommand 2",
        .name = "cmd2",
        .exec = runSubcmd2,
        .options = &.{
            .{
                .help = "option b",
                .short_name = 'b',
                .long_name = "beta",
                .ref = cli.ValueRef{ .boolean = &config2.b },
            },
        },
    };

    const rootCmd: cli.Command = .{
        .desc = "ejemplo numero dos",
        .subcommands = &.{ subcmd1, subcmd2 },
        .options = &.{
            .{
                .help = "option root",
                .short_name = 'r',
                .long_name = "root",
                .ref = cli.ValueRef{ .boolean = &config.r },
            },
        },
    };

    try cli.parseCommandLine(allocator, &rootCmd, cli.ParserOpts{});
}

fn runSubcmd1() !void {
    print("running subcommand one\n", .{});
    print("option r is {any}\n", .{config.r});
    print("option a is {any}\n", .{config1.a});
}

fn runSubcmd2() !void {
    print("running subcommand two\n", .{});
    print("option r is {any}\n", .{config.r});
    print("option b is {any}\n", .{config2.b});
}
