const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const wgpu_native_dep = b.dependency("wgpu_native_zig", .{}).module("wgpu");

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "wgpu_example",
        .root_module = exe_mod,
    });

    exe.root_module.addImport("wgpu", wgpu_native_dep);

    exe.linkFramework("Metal");
    exe.linkFramework("Foundation");
    exe.linkFramework("MetalPerformanceShaders");
    exe.linkFramework("QuartzCore");
    exe.linkFramework("Accelerate"); // For BLAS/LAPACK functions

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
