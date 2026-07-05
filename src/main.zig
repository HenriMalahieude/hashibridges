const std = @import("std");
const globals = @import("./globals.zig");
const boardImpl = @import("./board.zig");
const raylib = globals.raylib;
const Io = std.Io;

//NOTE: [*c]T is the c pointer type

var difficulty : globals.Difficulty = globals.Difficulty.Medi;

var viewingPrimary: bool = true;
var board: boardImpl.Board = undefined;
var board_bak: boardImpl.Board = undefined;

//init : std.process.Init as input
pub fn main() !void {
    //const arena: std.mem.Allocator = init.arena.allocator();

    std.debug.print("GAME: Initializing window of size {d} ^ 2\n", .{globals.window_square});
    raylib.InitWindow(globals.window_square, globals.window_square, "Test Window");

    board.Generate(globals.DifficultyOptions.get(difficulty), &board_bak);

    while (!raylib.WindowShouldClose()) {
        //NOTE: Mobile seems to handle interactions before the drawing better
        if (raylib.IsKeyReleased(raylib.KEY_Q)) {
            board.Generate(globals.DifficultyOptions.get(difficulty), &board_bak);
            viewingPrimary = true;
        }
        if (raylib.IsKeyReleased(raylib.KEY_W)) {
            board.StaticCopyTo(&board_bak);
            board.ResolveUnconnectedSubgraphs();
        }
        if (raylib.IsKeyReleased(raylib.KEY_E)) viewingPrimary = !viewingPrimary;

        raylib.BeginDrawing();
            raylib.ClearBackground(globals.bg_color);

            if (viewingPrimary) board.Draw()
            else board_bak.Draw();
        raylib.EndDrawing();
    }
}
