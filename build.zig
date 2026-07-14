const std = @import("std");

//const raylib_header = "~/Desktop/raylib/src/";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //Raylib stuff
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const exe = b.addExecutable(.{
        .name = "hashibridges",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    //Raylib dependencies
    if (target.result.os.tag == std.Target.Os.Tag.linux) {
        exe.root_module.linkSystemLibrary("GL", .{});
        exe.root_module.linkSystemLibrary("m", .{});
        exe.root_module.linkSystemLibrary("dl", .{});
        exe.root_module.linkSystemLibrary("X11", .{});
    } else if (target.result.os.tag == std.Target.Os.Tag.windows) {
        return error.WindowsNotImplemented;
    } else return error.OSNotHandled;

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
