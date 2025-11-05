const std = @import("std");
const cli = @import("root.zig");

const Allocator = std.mem.Allocator;

pub const Parser = struct {
    pub fn parseCommandLine(a: Allocator, commands: []const cli.Command) !void {
        const args = try std.process.argsAlloc(a);
        defer std.process.argsFree(a, args);

        var pos: usize = 0;
        var lastcommand: ?*const cli.Command = null;
        while (pos < args.len) {
            const arg = args[pos];

            if (isShortArg(arg)) {
                lastcommand = null;
                for (0..commands.len) |idx| {
                    const c = &commands[idx];
                    if (std.mem.eql(u8, c.short_name, arg[1.. :0])) {
                        c.ref.boolean.* = true;
                        if (c.hasparams) {
                            std.debug.print(">>>)) {s}\n", .{c.help});
                            lastcommand = c;
                        }
                    }
                }
            }

            if (isLongArg(arg)) {
                lastcommand = null;
                for (0..commands.len) |idx| {
                    const c = &commands[idx];
                    if (std.mem.eql(u8, c.long_name, arg[2.. :0])) {
                        c.ref.boolean.* = true;
                        if (c.hasparams) {
                            std.debug.print(">>>)) {s}\n", .{c.help});
                            lastcommand = c;
                        }
                    }
                }
            }

            if (arg[0] != '-') {
                if (lastcommand) |l| {
                    std.debug.print(">>> {s} - {s}\n", .{ l.help, arg });
                    const arg2 = try std.mem.Allocator.dupeZ(a, u8, arg);
                    try l.params.append(a, arg2);
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
