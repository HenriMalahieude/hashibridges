const std = @import("std");

pub const raylib = @cImport(@cInclude("raylib.h"));

/// Interface constants
pub const window_square : u16 = 800; // Width and Height
pub const interface_margin : u16 = 100; // Margin around the board

pub const max_board_square : u8 = 20;

pub const bg_color = raylib.WHITE;
pub const tx_color = raylib.BLACK;

pub const Difficulty = enum {
    Easy,
    Medium,
    Hard,
    Crazy
};

pub const DifficultyNodes = std.EnumArray(Difficulty, u8).init(.{
    .Easy = 5,
    .Medium = 10,
    .Hard = 15,
    .Crazy = 20,
});
