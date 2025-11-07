const std = @import("std");

const Example = struct {
    name: [:0]const u8,
    path: [:0]const u8,
};

const examples = [_]Example{
    .{
        .name = "example1",
        .path = "examples/example1.zig",
    },
    .{
        .name = "example2",
        .path = "examples/example2.zig",
    },
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const lib_mod = b.addModule("zcliconfig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zcliconfig",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    for (examples) |ex| {
        const example_mod = b.addModule(ex.name, .{
            .root_source_file = b.path(ex.path),
            .target = target,
            .optimize = optimize,
        });

        const example = b.addExecutable(.{
            .name = ex.name,
            .root_module = example_mod,
        });
        example.root_module.addImport("zcliconfig", lib_mod);
        b.installArtifact(example);
        b.default_step.dependOn(&example.step);
    }
}
