const std = @import("std");
const rlz = @import("raylib_zig");

//const raylib_header = "~/Desktop/raylib/src/";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const run_step = b.step("run", "Run the application");

    //Raylib stuff
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "hashibridges",
        .root_module = exe_mod,
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

        b.installArtifact(exe);
        const run_exe = b.addRunArtifact(exe);
        run_step.dependOn(&run_exe.step);
    } else if (target.result.os.tag == std.Target.Os.Tag.windows) {
        return error.WindowsNotImplemented;
    } else if (target.query.os_tag == .emscripten) { //-Dtarget=wasm32-emscripten
        const emsdk = rlz.emsdk;
        const wasm = b.addLibrary(.{
            .name = "hashibridges",
            .root_module = exe_mod,
        });

        const install_dir: std.Build.InstallDir = .{ .custom = "web" };
        const emcc_flags = emsdk.emccDefaultFlags(b.allocator, .{ .optimize = optimize });
        const emcc_settings = emsdk.emccDefaultSettings(b.allocator, .{ .optimize = optimize });

        const emcc_step = emsdk.emccStep(b, raylib_artifact, wasm, .{
            .optimize = optimize,
            .flags = emcc_flags,
            .settings = emcc_settings,
            .install_dir = install_dir,
        });
        b.getInstallStep().dependOn(emcc_step);

        const html_filename = try std.fmt.allocPrint(b.allocator, "{s}.html", .{wasm.name});
        const emrun_step = emsdk.emrunStep(
            b,
            b.getInstallPath(install_dir, html_filename),
            &.{},
        );

        emrun_step.dependOn(emcc_step);
        run_step.dependOn(emrun_step);
    } else return error.OSNotHandled;
}
