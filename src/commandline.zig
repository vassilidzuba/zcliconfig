// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const cli = @import("root.zig");

const Allocator = std.mem.Allocator;

const CommandLineParserError = error{
    ParameterMissing,
    OptionMissing,
};

pub const ParserOpts = struct {
    allow_multiple_short_options: bool = false,
};

pub fn parseCommandLine(a: Allocator, cmd: *const cli.Command, parserOpts: ParserOpts) !void {
    const args = try argsAlloc(a);
    defer argsFree(a, args);

    try parseArguments(a, cmd, args, parserOpts);
}

// copy slice of u_ to slice of
//fn copySlices([][:0]u8) [][:8]const u8 {

//}

pub fn parseArguments(a: Allocator, cmd: *const cli.Command, args: [][:0]const u8, parserOpts: ParserOpts) !void {
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
            if (!skipNextArg) {
                try checkMandatory(cmd, args[0..pos]);
            }

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

    try checkMandatory(cmd, args);

    if (cmd.exec) |exec| {
        try exec(a);
    }
}

fn processOptionValue(opt: *const cli.Option, args: [][:0]const u8, pos: usize) !bool {
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

            if (pos >= args.len - 1 or args[pos + 1][0] == '-') {
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

fn checkMandatory(command: *const cli.Command, args: [][:0]const u8) !void {
    for (command.options) |opt| {
        if (opt.mandatory) {
            var present: bool = false;
            for (args) |arg| {
                if (isOption(&opt, arg)) {
                    present = true;
                    break;
                }
            }
            if (!present) {
                std.debug.print("missing option : ", .{});
                if (opt.short_name) |sn| {
                    std.debug.print(" -{c}", .{sn});
                }
                if (opt.long_name) |ln| {
                    std.debug.print(" --{s}", .{ln});
                }
                std.debug.print("\n", .{});
                return CommandLineParserError.OptionMissing;
            }
        }
    }
}

fn isOption(opt: *const cli.Option, arg: []const u8) bool {
    if (arg[0] == '-') {
        if (arg[1] == '-') {
            if (arg.len > 2 and opt.long_name != null) {
                if (std.mem.eql(u8, arg[2.. :0], opt.long_name.?)) {
                    return true;
                }
            }
        } else {
            // to do : support aggregated options
            if (opt.short_name) |sn| {
                if (sn == arg[1]) {
                    return true;
                }
            }
        }
    }

    return false;
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

test "missing mandatory option" {
    const ta = std.testing.allocator;

    var config = struct {
        alpha: ?bool = null,
        beta: ?[:0]const u8 = null,
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
        .ref = cli.ValueRef{ .string = &config.beta },
        .mandatory = true,
    } } };

    var args = [_][:0]const u8{ "program", "-a" };

    const err = parseArguments(ta, &command, &args, cli.ParserOpts{});
    try std.testing.expectError(error.OptionMissing, err);
}

// next function copied from the standard library but
// returns ![][:0]const u8 instead of ![][:0]u8
// usefull for testing when the atguments are given as an array of liteerals
pub fn argsAlloc(allocator: std.mem.Allocator) ![][:0]const u8 {
    // TODO refactor to only make 1 allocation.
    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();

    var contents = std.array_list.Managed(u8).init(allocator);
    defer contents.deinit();

    var slice_list = std.array_list.Managed(usize).init(allocator);
    defer slice_list.deinit();

    while (it.next()) |arg| {
        try contents.appendSlice(arg[0 .. arg.len + 1]);
        try slice_list.append(arg.len);
    }

    const contents_slice = contents.items;
    const slice_sizes = slice_list.items;
    const slice_list_bytes = try std.math.mul(usize, @sizeOf([]u8), slice_sizes.len);
    const total_bytes = try std.math.add(usize, slice_list_bytes, contents_slice.len);
    const buf = try allocator.alignedAlloc(u8, .of([]u8), total_bytes);
    errdefer allocator.free(buf);

    const result_slice_list = std.mem.bytesAsSlice([:0]const u8, buf[0..slice_list_bytes]);
    const result_contents = buf[slice_list_bytes..];
    @memcpy(result_contents[0..contents_slice.len], contents_slice);

    var contents_index: usize = 0;
    for (slice_sizes, 0..) |len, i| {
        const new_index = contents_index + len;
        result_slice_list[i] = result_contents[contents_index..new_index :0];
        contents_index = new_index + 1;
    }

    return result_slice_list;
}

pub fn argsFree(allocator: Allocator, args_alloc: []const [:0]const u8) void {
    var total_bytes: usize = 0;
    for (args_alloc) |arg| {
        total_bytes += @sizeOf([]u8) + arg.len + 1;
    }
    const unaligned_allocated_buf = @as([*]const u8, @ptrCast(args_alloc.ptr))[0..total_bytes];
    const aligned_allocated_buf: []align(@alignOf([]u8)) const u8 = @alignCast(unaligned_allocated_buf);
    return allocator.free(aligned_allocated_buf);
}
