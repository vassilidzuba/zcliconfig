// Copyright 2025, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const cli = @import("root.zig");

const Allocator = std.mem.Allocator;

pub const ParserOpts = struct {
    allow_multiple_short_options: bool = false,
};

pub const Parser = struct {
    pub fn parseCommandLine(a: Allocator, confdesc: *const cli.ConfigurationDescription, parserOpts: ParserOpts) !void {
        const args = try std.process.argsAlloc(a);
        defer std.process.argsFree(a, args);

        if (confdesc.program) |ps| {
            const prog = try std.mem.Allocator.dupeZ(a, u8, args[0]);
            ps.* = prog;
        }

        var pos: usize = 1;
        var lastoption: ?*const cli.Option = null;
        while (pos < args.len) {
            const arg = args[pos];

            if (isShortArg(arg)) {
                std.debug.print("heheheh\n", .{});
                lastoption = null;
                if (parserOpts.allow_multiple_short_options) {
                    for (arg[1.. :0]) |c| {
                        for (0..confdesc.options.len) |idx| {
                            const opt = &confdesc.options[idx];
                            if (opt.short_name == c) {
                                opt.ref.boolean.* = true;
                                if (opt.hasparams) {
                                    lastoption = opt;
                                }
                            }
                        }
                    }
                } else {
                    for (0..confdesc.options.len) |idx| {
                        const opt = &confdesc.options[idx];
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
                for (0..confdesc.options.len) |idx| {
                    const c = &confdesc.options[idx];
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
                } else {
                    const arg2 = try std.mem.Allocator.dupeZ(a, u8, arg);
                    try confdesc.operands.append(a, arg2);
                }
            }

            pos += 1;
        }
    }

    fn isShortArg(arg: [:0]u8) bool {
        return arg.len > 1 and arg[0] == '-' and arg[1] != '-';
    }

    fn isLongArg(arg: [:0]u8) bool {
        return arg.len > 1 and arg[0] == '-' and arg[1] == '-';
    }
};
