const std = @import("std");
const globals = @import("./globals.zig");
const boardImpl = @import("./board.zig");
const raylib = globals.raylib;
const Io = std.Io;

//NOTE: [*c]T is the c pointer type

var difficulty : globals.Difficulty = globals.Difficulty.Easy;
var board : boardImpl.Board = undefined;

//init : std.process.Init as input
pub fn main() !void {
    //const arena: std.mem.Allocator = init.arena.allocator();

    std.debug.print("GAME: Initializing window of size {d} ^ 2\n", .{globals.window_square});
    raylib.InitWindow(globals.window_square, globals.window_square, "Test Window");

    board.Generate(globals.DifficultyOptions.get(difficulty));

    while (!raylib.WindowShouldClose()) {
        raylib.BeginDrawing();
            raylib.ClearBackground(globals.bg_color);

            board.Draw();
        raylib.EndDrawing();

        if (raylib.IsKeyReleased(raylib.KEY_E)) board.ConnectionStep(1);
        if (raylib.IsKeyReleased(raylib.KEY_W)) board.ConnectionStep(4);
        if (raylib.IsKeyReleased(raylib.KEY_Q)) board.Generate(globals.DifficultyOptions.get(difficulty));
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
