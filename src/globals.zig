const std = @import("std");

pub const raylib = @cImport(@cInclude("raylib.h"));

/// Width and Height
pub const window_square : i16 = 800;

pub const max_board_square : i16 = 20;

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
