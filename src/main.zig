const std = @import("std");
const globals = @import("./globals.zig");
const boardImpl = @import("./board.zig");
const raylib = globals.raylib;
const raygui = globals.raygui;
const Io = std.Io;

//NOTE: [*c]T is the c pointer type


//var viewingPrimary: bool = true;
var board: boardImpl.Board = undefined;
//var board_bak: boardImpl.Board = undefined;

//Quiet a stupid emscripten error in 0.16.0
//NOTE: This means that you can't use any 'std.debug.print' in your program, even if compiling with Release versions
pub const std_options_debug_io = std.Io.failing;
pub const panic = std.debug.no_panic;

//init : std.process.Init as input
pub fn main() !void {
    //const arena: std.mem.Allocator = init.arena.allocator();

    //Complaint: For some reason NONE OF THESE WORK
    //raygui.setStyle(.default, .{.default=.text_size}, @intCast(globals.interface_font_sz));
    //raygui.setStyle(.button, .{.control=.text_color_normal}, raylib.colorToInt(raylib.Color.black));
    //raygui.setStyle(.button, .{.control=.text_color_focused}, raylib.colorToInt(raylib.Color.gray));
    //raygui.setStyle(.button, .{.control=.text_color_pressed}, 0xFFFFFF);

    //std.debug.print("GAME: Initializing window of size {d} ^ 2\n", .{globals.window_square});
    raylib.initWindow(globals.window_square, globals.window_square, "Test Window");

    board.Generate(globals.DifficultyOptions.get(globals.difficulty), null);

    while (!raylib.windowShouldClose()) {
        //NOTE: Mobile seems to handle interactions before the drawing better
        board.Interact();

        raylib.beginDrawing();
            raylib.clearBackground(globals.bg_color);

            board.Draw();
        raylib.endDrawing();
    }
}
