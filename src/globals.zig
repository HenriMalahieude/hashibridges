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
    .Easy = .{.Nodes =  12, .Square =  5, .DoubleChance = 20}, // 12 /  25 = .50
    .Medi = .{.Nodes =  40, .Square = 10, .DoubleChance = 40}, // 60 / 100 = .60
    .Hard = .{.Nodes =  90, .Square = 15, .DoubleChance = 60}, //125 / 225 = .60
    .Crzy = .{.Nodes = 160, .Square = 20, .DoubleChance = 60}, //250 / 400 = .625
});

