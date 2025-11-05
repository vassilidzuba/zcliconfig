const std = @import("std");

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

    {
        const example1_mod = b.addModule("example1", .{
            .root_source_file = b.path("examples/example1.zig"),
            .target = target,
            .optimize = optimize,
        });

        const example1 = b.addExecutable(.{
            .name = "example1",
            .root_module = example1_mod,
        });
        example1.root_module.addImport("zcliconfig", lib_mod);
        b.installArtifact(example1);
        b.default_step.dependOn(&example1.step);
    }
}
