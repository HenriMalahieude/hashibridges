const std = @import("std");
const assert = std.debug.assert;

const globals = @import("globals.zig");
const raylib = globals.raylib;

/// Represents the game state
pub const Board = struct {
    const ConnectionType = enum { None, Single, Double, Void };
    const GameState = enum { Ungenerated, Running, Complete };
    const Directions = enum { Right, Down }; //no need to store duplicate information

    const Node = struct {
        x : u16 = 0,
        y : u16 = 0,
        connections : std.EnumArray(Directions, ConnectionType),
        user_connections : std.EnumArray(Directions, ConnectionType),
    };

    grid : [globals.MaxNodes] Node = undefined,
    nodes : u16 = 0,
    square: u16 = 0,

    state : GameState = GameState.Ungenerated,

    fn LocateNode(self : *Board, x : u16, y : u16) ?usize {
        for (0..self.nodes) |i| {
            if (self.grid[i].x == x and self.grid[i].y == y) {
                return i;
            }
        }

        return null;
    }

    /// Generate a New Puzzle to be solved
    pub fn Generate(self : *Board, settings : globals.DifficultySetting) void {
        for (0..settings.Nodes) |i| {
            self.nodes = @truncate(i);

            var x: u16 = @intCast(raylib.GetRandomValue(0, settings.Square-1));
            var y: u16 = @intCast(raylib.GetRandomValue(0, settings.Square-1));
            while (self.LocateNode(x, y) != null) {
                x = @intCast(raylib.GetRandomValue(0, settings.Square-1));
                y = @intCast(raylib.GetRandomValue(0, settings.Square-1));
            }

            self.grid[i] = .{
                .x=x,
                .y=y,
                .connections = std.EnumArray(Directions, ConnectionType).init(.{
                    .Right = ConnectionType.Void,
                    .Down = ConnectionType.Void,
                }),

                .user_connections = std.EnumArray(Directions, ConnectionType).init(.{
                    .Right = ConnectionType.Void,
                    .Down = ConnectionType.Void,
                }),
            };
        }

        self.nodes = settings.Nodes;
        self.square = settings.Square;
    }

    /// Draw the Screen using Raylib
    pub fn Draw(self : *Board) void {
        const board_square: u32 = globals.window_square - globals.interface_margin;
        const node_space: u32 = board_square / @as(u32, self.square); //in pix
        const node_rd: u32 = node_space / 4; //radius, leave some room for bridges
        const text_sz: u32 = node_space / 5;

        //center of the start locations
        const strt_x: u32 = (globals.interface_margin/2) + (node_space/2);
        const strt_y: u32 = (globals.interface_margin/2) + (node_space/2);

        //Draw the Grid first
        for (0..self.square) |i| {
            const delta = @as(u32, @truncate(i)) * node_space;

            const rg_start: raylib.Vector2 = .{
                .x=@floatFromInt(strt_x),
                .y=@floatFromInt(strt_y+delta),
            };
            const cg_start: raylib.Vector2 = .{
                .x=@floatFromInt(strt_x+delta),
                .y=@floatFromInt(strt_y),
            };

            const rg_end: raylib.Vector2 = .{
                .x=@floatFromInt(strt_x + board_square - node_space),
                .y=rg_start.y,
            };
            const cg_end: raylib.Vector2 = .{
                .x=cg_start.x,
                .y=@floatFromInt(strt_y + board_square - node_space),
            };
            raylib.DrawLineV(rg_start, rg_end, raylib.GRAY);
            raylib.DrawLineV(cg_start, cg_end, raylib.GRAY);
        }

        //TODO: The bridges

        for (0..self.nodes) |i| {
            const nd: *Node = &self.grid[i];

            const pix_x: c_int = @intCast(strt_x + nd.x * node_space);
            const pix_y: c_int = @intCast(strt_y + nd.y * node_space);

            //Draw the Node
            raylib.DrawCircle(pix_x, pix_y, @floatFromInt(node_rd), raylib.BLACK);
            raylib.DrawCircle(pix_x, pix_y, @as(f32, @floatFromInt(node_rd)) * 0.9, globals.bg_color);

            //Draw the Bridge Count
            const buf = [_:0]u8{'0'}; //TODO: Get the amount
            const txtPixSz = raylib.MeasureTextEx(raylib.GetFontDefault(), &buf, @as(f32, @floatFromInt(text_sz)), 0);
            raylib.DrawText(&buf, pix_x - @as(u16, @intFromFloat(txtPixSz.x/2)), pix_y - @as(u16, @intFromFloat(txtPixSz.y/2)), @intCast(text_sz), globals.tx_color);

        }
    }

    fn ComputeNodeBridgeTotal(self : *Board, x : usize, y : usize) u16 {
        _ = self;
        _ = x;
        _ = y;
    }

    /// Interact with the board using Raylib
    pub fn Interact(self : *Board) void {
        _ = self;
    }
};
