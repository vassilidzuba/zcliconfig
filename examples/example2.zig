// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const print = std.debug.print;
const cli = @import("zcliconfig");

fn init(_: std.mem.Allocator) void {}

fn deinit(_: std.mem.Allocator) void {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    init(allocator);
    defer deinit(allocator);

    const subcmd1: cli.Command = .{
        .desc = "subcommand 1",
        .id = "cmd1",
        .exec = runSubcmd1,
    };

    const subcmd2: cli.Command = .{
        .desc = "subcommand 2",
        .id = "cmd2",
        .exec = runSubcmd2,
    };

    const rootCmd: cli.Command = .{
        .desc = "ejemplo numero dos",
        .subcommands = &.{ subcmd1, subcmd2 },
    };

    try cli.parseCommandLine(allocator, &rootCmd, cli.ParserOpts{});
}

fn runSubcmd1() !void {
    print("running subcommand one\n", .{});
}

fn runSubcmd2() !void {
    print("running subcommand two\n", .{});
}
