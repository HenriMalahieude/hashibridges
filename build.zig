const std = @import("std");

//const raylib_header = "~/Desktop/raylib/src/";

pub fn build(b: *std.Build) !void {
    const raylib_dir = b.option([] const u8, "raylib_dir", "Location of the raylib source including the header") orelse "~/Desktop/raylib/src/";

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hashibridges",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            //.target = b.resolveTargetQuery(.{
            //    .os_tag = if (windows) .windows else null,

            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    //Raylib stuff
    const rel_path = std.Build.LazyPath{ .cwd_relative = raylib_dir }; //construct relative from absolute
    exe.root_module.addIncludePath(rel_path); //header

    const lib_to_use = if (target.result.cpu.arch.isWasm()) "libs/web/libraylib.a" else "libs/desktop/libraylib.a";
    exe.root_module.addObjectFile(b.path(lib_to_use));

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
