// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const cli = @import("root.zig");

const Allocator = std.mem.Allocator;

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
    var lastoption: ?*const cli.Option = null;
    while (pos < args.len) {
        const arg = args[pos];

        if (isShortArg(arg)) {
            lastoption = null;
            if (parserOpts.allow_multiple_short_options) {
                for (arg[1.. :0]) |c| {
                    for (0..cmd.options.len) |idx| {
                        const opt = &cmd.options[idx];
                        if (opt.short_name == c) {
                            opt.ref.boolean.* = true;
                            if (opt.hasparams) {
                                lastoption = opt;
                            }
                        }
                    }
                }
            } else {
                for (0..cmd.options.len) |idx| {
                    const opt = &cmd.options[idx];
                    if (opt.short_name == arg[1]) {
                        opt.ref.boolean.* = true;
                        if (opt.hasparams) {
                            lastoption = opt;
                        }
                    }
                }
            }
        }

        if (isLongArg(arg)) {
            lastoption = null;
            for (0..cmd.options.len) |idx| {
                const c = &cmd.options[idx];
                if (c.long_name) |long_name| {
                    if (std.mem.eql(u8, long_name, arg[2.. :0])) {
                        c.ref.boolean.* = true;
                        if (c.hasparams) {
                            std.debug.print(">>>)) {s}\n", .{c.help});
                            lastoption = c;
                        }
                    }
                }
            }
        }

        if (arg[0] != '-') {
            if (lastoption) |l| {
                const arg2 = try std.mem.Allocator.dupeZ(a, u8, arg);
                try l.params.append(a, arg2);
                lastoption = null;
            } else if (cmd.subcommands.len != 0) {
                for (cmd.subcommands) |subcommand| {
                    if (std.mem.eql(u8, subcommand.id, arg)) {
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

fn isShortArg(arg: [:0]u8) bool {
    return arg.len > 1 and arg[0] == '-' and arg[1] != '-';
}

fn isLongArg(arg: [:0]u8) bool {
    return arg.len > 1 and arg[0] == '-' and arg[1] == '-';
}

fn processEnvvar(a: std.mem.Allocator, confdesc: *const cli.Command) !void {
    var envmap = try std.process.getEnvMap(a);
    defer envmap.deinit();

    for (confdesc.options) |opt| {
        if (opt.envvar) |envvar| {
            if (envmap.get(envvar)) |val| {
                opt.ref.boolean.* = true;
                const val2 = try std.mem.Allocator.dupeZ(a, u8, val);
                try opt.params.append(a, val2);
            }
        }
    }
}

fn checkMandatory(confdesc: *const cli.Command) !void {
    for (confdesc.options) |opt| {
        if (opt.mandatory) {
            if (opt.params.*.items.len == 0) {
                std.debug.print("missing option:", .{});
                if (opt.short_name) |short_name| {
                    std.debug.print(" -{c}", .{short_name});
                }
                if (opt.long_name) |long_name| {
                    std.debug.print(" --{s}", .{long_name});
                }
                std.debug.print("\n", .{});
            }
        }
    }
}
