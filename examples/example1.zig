const std = @import("std");
const print = std.debug.print;
const cli = @import("zcliconfig");

var config = struct {
    doalpha: bool = false,
    dobeta: bool = false,
    betaargs: std.ArrayList([:0]u8) = .empty,
    dogamma: bool = false,
}{};

fn init(_: std.mem.Allocator) void {}

fn deinit(a: std.mem.Allocator) void {
    for (config.betaargs.items) |val| {
        a.free(val);
    }
    config.betaargs.deinit(a);
}

pub fn log() void {
    print("-> alpha is {any}\n", .{config.doalpha});
    print("-> beta is {any}\n", .{config.dobeta});
    for (config.betaargs.items) |x| {
        print("    {s}\n", .{x});
    }
    print("-> gamma is {any}\n", .{config.dogamma});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    init(allocator);
    defer deinit(allocator);

    const commands: []const cli.Option = &.{
        .{ .help = "first option", .short_name = "a", .long_name = "alpha", .ref = cli.ValueRef{ .boolean = &config.doalpha } },
        .{ .help = "second option", .short_name = "b", .long_name = "beta", .ref = cli.ValueRef{
            .boolean = &config.dobeta,
        }, .hasparams = true, .params = &config.betaargs },
        .{ .help = "third option", .short_name = "c", .ref = cli.ValueRef{ .boolean = &config.dogamma } },
    };

    try cli.Parser.parseCommandLine(allocator, commands);

    log();
}
