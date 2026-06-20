const std = @import("std");
const assert = std.debug.assert;

const globals = @import("globals.zig");
const raylib = globals.raylib;


/// Represents the game state
pub const Board = struct {
    const ConnectionType = enum { None, Single, Double, Void };
    const GameState = enum { Ungenerated, Running, Complete };

    /// Edges from left to right
    edge_h : [globals.max_board_square-1][globals.max_board_square] ConnectionType = undefined, //horizontal
    user_h : [globals.max_board_square-1][globals.max_board_square] ConnectionType = undefined,

    /// Edges from top to bottom
    edge_v : [globals.max_board_square][globals.max_board_square-1] ConnectionType = undefined, //vertical
    user_v : [globals.max_board_square][globals.max_board_square-1] ConnectionType = undefined,

    /// Current State of the Game
    state : GameState = GameState.Ungenerated,

    /// Current Node Count of the Board
    nodes : u8 = 0,

    /// Generate a New Puzzle to be solved
    pub fn Generate(self : *Board, square : u8) void {
        self.nodes = square;

        for (0..globals.max_board_square-1) |small| { //defaults for the board
            for (0..globals.max_board_square) |big| {
                if (small >= square-1 or big >= square)  {
                    self.edge_h[small][big] = ConnectionType.Void;
                    self.edge_v[big][small] = ConnectionType.Void;
                } else {
                    self.edge_h[small][big] = ConnectionType.Double;
                    self.edge_v[big][small] = ConnectionType.Double;
                }
            }
        }
    }

    /// Draw the Screen using Raylib
    pub fn Draw(self : *Board) void {
        const board_square = globals.window_square - globals.interface_margin;
        const node_space = board_square / @as(u16, self.nodes); //in pix
        const text_sz = node_space / 5;

        // Draw the Nodes
        for (0..self.nodes) |x| {
            for (0..self.nodes) |y| {
                const am = self.ComputeNodeBridgeTotal(x, y);
                const pix_x = @as(u16, @truncate(x)) * node_space + (globals.interface_margin/2) + (node_space/2);
                const pix_y = @as(u16, @truncate(y)) * node_space + (globals.interface_margin/2) + (node_space/2);

                //Draw the Circle representing the node
                raylib.DrawCircle(pix_x, pix_y, node_space/4, raylib.BLACK);
                raylib.DrawCircle(pix_x, pix_y, node_space/5, globals.bg_color);

                //Draw the Text showing the bridge count
                const buf = [_:0]u8{'0'+am};
                const txtPixSz = raylib.MeasureTextEx(raylib.GetFontDefault(), &buf, text_sz, 0);
                raylib.DrawText(&buf, pix_x - @as(u16, @intFromFloat(txtPixSz.x/2)), pix_y - @as(u16, @intFromFloat(txtPixSz.y/2)), text_sz, globals.tx_color);

                //Draw the Edges to the right and bottom
                //TODO
            }
        }
    }

    fn ComputeNodeBridgeTotal(self : *Board, x : usize, y : usize) u8 {
        var total : u8 = 0;

        if (x != 0) { //left side
            const am = @intFromEnum(self.edge_h[x-1][y]);
            assert(am < 3);
            total += am;
        }

        if (x < self.nodes-1) { //right side
            const am = @intFromEnum(self.edge_h[x][y]);
            assert(am < 3);
            total += am;
        }

        if (y != 0) { //above
            const am = @intFromEnum(self.edge_v[x][y-1]);
            assert(am < 3);
            total += am;
        }

        if (y < self.nodes-1) { //below
            const am = @intFromEnum(self.edge_v[x][y]);
            assert(am < 3);
            total += am;
        }

        assert(total <= 8);
        return total;
    }

    /// Interact with the board using Raylib
    pub fn Interact(self : *Board) void {
        _ = self;
    }
};
