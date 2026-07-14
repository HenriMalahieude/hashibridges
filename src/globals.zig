const std = @import("std");

pub const raylib = @import("raylib");
pub const raygui = @import("raygui");

/// Interface constants
pub const window_square: u16 = 800; // Width and Height
pub const interface_margin: u16 = 100; // Margin around the board

pub const max_board_square: u16 = 20;
pub const min_node_dist: u16 = 1; //between nodes there must be N empty spaces
//pub const max_node_retry: u16 = 10; //maximum amount of times a node will retry when failing the distance check

pub const bg_color = raylib.Color.white;
pub const tx_color = raylib.Color.black;

pub const Difficulty = enum {
    Easy,
    Medi,
    Hard,
    Crzy
};

pub const DifficultySetting = struct {
    Nodes: u16,
    Square: u16,
    DoubleChance: u16, //between 0 and 100
};

pub const MaxNodes = DifficultyOptions.get(Difficulty.Crzy).Nodes;
pub const DifficultyOptions = std.EnumArray(Difficulty, DifficultySetting).init(.{
    .Easy = .{.Nodes = 10, .Square =  6, .DoubleChance = 40}, //aiming for a 30% filling of the board
    .Medi = .{.Nodes = 30, .Square = 12, .DoubleChance = 50},
    .Hard = .{.Nodes = 58, .Square = 14, .DoubleChance = 55},
    .Crzy = .{.Nodes = 76, .Square = 16, .DoubleChance = 60},
});

