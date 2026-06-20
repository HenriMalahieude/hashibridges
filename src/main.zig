const std = @import("std");
const raylib = @cImport(@cInclude("raylib.h"));
const globals = @import("./globals.zig");
const Io = std.Io;

//NOTE: [*c]T is the c pointer type

//init : std.process.Init as input
pub fn main() !void {
    //const arena: std.mem.Allocator = init.arena.allocator();

    std.debug.print("GAME: Initializing window of size {d} ^ 2\n", .{globals.window_square});
    raylib.InitWindow(globals.window_square, globals.window_square, "Test Window");

    while (!raylib.WindowShouldClose()) {
        raylib.BeginDrawing();
            raylib.ClearBackground(raylib.DARKGREEN);

            raylib.DrawText("TODO", globals.window_square / 2, globals.window_square / 2, 12, raylib.BLACK);
        raylib.EndDrawing();
    }

    // Accessing command line arguments:
    //const args = try init.minimal.args.toSlice(arena);
    //for (args) |arg| {
    //    std.log.info("arg: {s}", .{arg});
    //}

    // In order to do I/O operations need an `Io` instance.
    //const io = init.io;

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    //var stdout_buffer: [1024]u8 = undefined;
    //var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    //const stdout_writer = &stdout_file_writer.interface;

    //try hashibridges.printAnotherMessage(stdout_writer);

    //try stdout_writer.flush(); // Don't forget to flush!
}
