const std = @import("std");
const globals = @import("globals.zig");
const raylib = globals.raylib;

/// Represents the game state
pub const Board = struct {
    const ConnectionType = enum { None, Single, Double, Void };
    const GameState = enum { Ungenerated, Running, Complete };

    /// Edges from left to right
    edge_h : [globals.max_board_square-1][globals.max_board_square] ConnectionType = undefined, //horizontal

    /// Edges from top to bottom
    edge_v : [globals.max_board_square][globals.max_board_square-1] ConnectionType = undefined, //vertical

    /// Current State of the Game
    state : GameState = GameState.Ungenerated,

    /// Generate a New Puzzle to be solved
    pub fn Generate(self : *Board, square : u16) void {
        _ = square;
        for (0..self.edge_h.len) |x| {
            for (0.. self.edge_h[x].len) |y| {
                self.edge_h[x][y] = ConnectionType.Void;
            }
        }

        for (0..self.edge_v.len-1) |x| {
            for (0.. self.edge_v[x].len-1) |y| {
                self.edge_h[x][y] = ConnectionType.Void;
            }
        }
    }

    /// Using
    pub fn Draw(self : *Board) void {
        _ = self;

        raylib.DrawText("TODO", globals.window_square / 2, globals.window_square / 2, 24, raylib.BLACK);
    }
};
