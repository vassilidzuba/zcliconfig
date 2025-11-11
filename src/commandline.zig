// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const cli = @import("root.zig");

const Allocator = std.mem.Allocator;

const CommandLineParserError = error{
    ParameterMissing,
};

pub const ParserOpts = struct {
    allow_multiple_short_options: bool = false,
};

pub fn parseCommandLine(a: Allocator, cmd: *const cli.Command, parserOpts: ParserOpts) !void {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    try parseArguments(a, cmd, args, parserOpts);
}

pub fn parseArguments(a: Allocator, cmd: *const cli.Command, args: [][:0]u8, parserOpts: ParserOpts) !void {
    if (cmd.program) |ps| {
        const prog = try std.mem.Allocator.dupeZ(a, u8, args[0]);
        ps.* = prog;
    }

    try processEnvvar(a, cmd);

    var pos: usize = 1;
    var skipNextArg: bool = false;

    while (pos < args.len) {
        const arg = args[pos];

        if (isShortArg(arg)) {
            if (parserOpts.allow_multiple_short_options) {
                for (arg[1.. :0]) |c| {
                    for (0..cmd.options.len) |idx| {
                        const opt = &cmd.options[idx];
                        if (opt.short_name == c) {
                            skipNextArg = try processOptionValue(opt, args, pos);
                        }
                    }
                }
            } else {
                for (0..cmd.options.len) |idx| {
                    const opt = &cmd.options[idx];
                    if (opt.short_name == arg[1]) {
                        skipNextArg = try processOptionValue(opt, args, pos);
                    }
                }
            }
        }

        if (isLongArg(arg)) {
            for (0..cmd.options.len) |idx| {
                const opt = &cmd.options[idx];
                if (opt.long_name) |long_name| {
                    if (std.mem.eql(u8, long_name, arg[2.. :0])) {
                        skipNextArg = try processOptionValue(opt, args, pos);
                    }
                }
            }
        }

        if (arg[0] != '-') {
            if (skipNextArg) {
                skipNextArg = false;
            } else if (cmd.subcommands.len != 0) {
                for (cmd.subcommands) |subcommand| {
                    if (std.mem.eql(u8, subcommand.name, arg)) {
                        try parseArguments(a, &subcommand, args[pos..], parserOpts);
                        return;
                    }
                }
                std.debug.print("unknown subcommand: {s}\n", .{arg});
                return;
            } else {
                const arg2 = try std.mem.Allocator.dupeZ(a, u8, arg);
                try cmd.operands.append(a, arg2);
            }
        }

        pos += 1;
    }

    try checkMandatory(cmd);

    if (cmd.exec) |exec| {
        try exec();
    }
}

fn processOptionValue(opt: *const cli.Option, args: [][:0]u8, pos: usize) !bool {
    const arg: [:0]const u8 = args[pos];
    var param: ?[:0]const u8 = null;

    for (2..arg.len) |idx| {
        if (arg[idx] == '=') {
            param = arg[idx + 1 .. arg.len :0];
        }
    }

    switch (opt.ref) {
        .boolean => opt.ref.boolean.* = true,
        .string => {
            if (param) |p| {
                opt.ref.string.* = p;
                return true;
            }
            if (pos >= args.len or args[pos + 1][0] == '-') {
                std.debug.print("missing parameter for option {s}\n", .{args[pos]});
                return error.ParameterMissing;
            }
            opt.ref.string.* = args[pos + 1];
            return true;
        },
    }
    return false;
}

fn isShortArg(arg: [:0]const u8) bool {
    return arg.len > 1 and arg[0] == '-' and arg[1] != '-';
}

fn isLongArg(arg: [:0]const u8) bool {
    return arg.len > 1 and arg[0] == '-' and arg[1] == '-';
}

fn processEnvvar(a: std.mem.Allocator, confdesc: *const cli.Command) !void {
    var envmap = try std.process.getEnvMap(a);
    defer envmap.deinit();

    for (confdesc.options) |opt| {
        if (opt.envvar) |envvar| {
            if (envmap.get(envvar)) |val| {
                const val2 = try std.mem.Allocator.dupeZ(a, u8, val);
                switch (opt.ref) {
                    .string => |value| setValue(value, val2),
                    .boolean => unreachable,
                }
            }
        }
    }
}

fn setValue(ref: *?[:0]const u8, val: [:0]const u8) void {
    ref.*.? = val;
}

fn checkMandatory(_: *const cli.Command) !void {
    //    for (confdesc.options) |opt| {
    //        if (opt.mandatory) {
    //            if (opt.params.*.items.len == 0) {
    //                std.debug.print("missing option:", .{});
    //                if (opt.short_name) |short_name| {
    //                    std.debug.print(" -{c}", .{short_name});
    //                }
    //                if (opt.long_name) |long_name| {
    //                    std.debug.print(" --{s}", .{long_name});
    //                }
    //                std.debug.print("\n", .{});
    //            }
    //        }
    //    }
}

test "options without parameter" {
    const ta = std.testing.allocator;

    var config = struct {
        alpha: ?bool = null,
        beta: ?bool = null,
    }{};
    var command: cli.Command = .{ .desc = "test", .options = &.{ .{
        .help = "first option",
        .short_name = 'a',
        .long_name = "alpha",
        .ref = cli.ValueRef{ .boolean = &config.alpha },
    }, .{
        .help = "first option",
        .short_name = 'b',
        .long_name = "beta",
        .ref = cli.ValueRef{ .boolean = &config.beta },
    } } };

    var args = [_][:0]const u8{ "program", "-a", "--beta" };

    try std.testing.expect(config.alpha == null);
    try std.testing.expect(config.beta == null);

    try parseArguments(ta, &command, &args, cli.ParserOpts{});

    try std.testing.expect(config.alpha.?);
    try std.testing.expect(config.beta.?);
}

test "options with parameter" {
    const ta = std.testing.allocator;

    var config = struct {
        alpha: ?[:0]const u8 = null,
        beta: ?[:0]const u8 = null,
    }{};
    var command: cli.Command = .{ .desc = "test", .options = &.{ .{
        .help = "first option",
        .short_name = 'a',
        .long_name = "alpha",
        .ref = cli.ValueRef{ .string = &config.alpha },
    }, .{
        .help = "first option",
        .short_name = 'b',
        .long_name = "beta",
        .ref = cli.ValueRef{ .string = &config.beta },
    } } };

    var args = [_][:0]const u8{ "program", "-a", "foo", "--beta", "bar" };

    try parseArguments(ta, &command, &args, cli.ParserOpts{});

    try std.testing.expectEqualSlices(u8, config.alpha.?, "foo");
    try std.testing.expectEqualSlices(u8, config.beta.?, "bar");

    var args2 = [_][:0]const u8{ "program", "-a=foo", "--beta", "bar" };

    try parseArguments(ta, &command, &args2, cli.ParserOpts{});

    try std.testing.expectEqualSlices(u8, config.alpha.?, "foo");
    try std.testing.expectEqualSlices(u8, config.beta.?, "bar");
}

test "options with operands" {
    const ta = std.testing.allocator;

    var config = struct {
        alpha: ?bool = false,
        beta: ?bool = false,
        operands: std.ArrayList([:0]u8) = .empty,
    }{};
    var command: cli.Command = .{
        .desc = "test",
        .options = &.{ .{
            .help = "first option",
            .short_name = 'a',
            .long_name = "alpha",
            .ref = cli.ValueRef{ .boolean = &config.alpha },
        }, .{
            .help = "first option",
            .short_name = 'b',
            .long_name = "beta",
            .ref = cli.ValueRef{ .boolean = &config.beta },
        } },
        .operands = &config.operands,
    };

    var args = [_][:0]const u8{ "program", "-a", "--beta", "iota", "lambda" };

    try std.testing.expect(!config.alpha.?);
    try std.testing.expect(!config.beta.?);

    try parseArguments(ta, &command, &args, cli.ParserOpts{});

    try std.testing.expect(config.alpha.?);
    try std.testing.expect(config.beta.?);

    try std.testing.expectEqualSlices(u8, config.operands.items[0], "iota");
    try std.testing.expectEqualSlices(u8, config.operands.items[1], "lambda");

    for (config.operands.items) |item| {
        ta.free(item);
    }
    config.operands.deinit(ta);
}

test "missing parameter" {
    const ta = std.testing.allocator;

    var config = struct {
        alpha: ?[:0]const u8 = null,
        beta: ?[:0]const u8 = null,
    }{};
    var command: cli.Command = .{ .desc = "test", .options = &.{ .{
        .help = "first option",
        .short_name = 'a',
        .long_name = "alpha",
        .ref = cli.ValueRef{ .string = &config.alpha },
    }, .{
        .help = "first option",
        .short_name = 'b',
        .long_name = "beta",
        .ref = cli.ValueRef{ .string = &config.beta },
    } } };

    var args = [_][:0]const u8{ "program", "-a", "--beta", "bar" };

    const err = parseArguments(ta, &command, &args, cli.ParserOpts{});
    try std.testing.expectError(error.ParameterMissing, err);
}
