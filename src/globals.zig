const std = @import("std");

pub const raylib = @cImport(@cInclude("raylib.h"));

/// Interface constants
pub const window_square : u16 = 800; // Width and Height
pub const interface_margin : u16 = 100; // Margin around the board

pub const max_board_square : u16 = 20;

pub const bg_color = raylib.WHITE;
pub const tx_color = raylib.BLACK;

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
    .Easy = .{.Nodes =  10, .Square =  5, .DoubleChance = 20}, // 10 /  25
    .Medi = .{.Nodes =  50, .Square = 10, .DoubleChance = 40}, // 50 / 100
    .Hard = .{.Nodes = 100, .Square = 15, .DoubleChance = 60}, //100 / 225
    .Crzy = .{.Nodes = 200, .Square = 20, .DoubleChance = 60}, //200 / 400
});

