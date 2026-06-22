const std = @import("std");
const assert = std.debug.assert;

const globals = @import("globals.zig");
const raylib = globals.raylib;

// Somehow this isn't located within raylib.h even though it's in there?
pub extern "c" fn DrawLineDashed(a: raylib.Vector2, b: raylib.Vector2, c: c_int, d: c_int, e: raylib.Color) void;

/// Represents the game state
pub const Board = struct {
    const ConnectionType = enum { None, Single, Double };
    const GameState = enum { Ungenerated, Running, Complete };
    const Directions = enum { Right, Down }; //no need to store duplicate information

    const Node = struct {
        id: u16 = 0,
        x : u16 = 0,
        y : u16 = 0,
        bridges: u8 = 0,
        connections : std.EnumArray(Directions, ConnectionType) = undefined,
        user_connections : std.EnumArray(Directions, ConnectionType) = undefined,
    };

    grid : [globals.MaxNodes] Node = undefined,
    nodes : u16 = 0,
    square: u16 = 0,

    state : GameState = GameState.Ungenerated,

    fn NodeLocateCoord(self : *Board, x : u16, y : u16) ?usize {
        for (0..self.nodes) |i| {
            if (self.grid[i].x == x and self.grid[i].y == y) {
                return i;
            }
        }

        return null;
    }

    fn NodeLocateDir(self: *Board, x: u16, y: u16, dir: Directions, pos: bool) ?usize{
        var out: ?usize = null;
        var dist: usize = std.math.maxInt(usize);
        for (0..self.nodes) |i| {
            const n = &self.grid[i];
            if (n.x == x and n.y == y) continue; //skip same one

            var base_cmp: u16 = x;
            var othr_cmp: u16 = n.x;
            var same_axis: bool = (y == n.y);
            if (dir == Directions.Down) {
                base_cmp = y;
                othr_cmp = n.y;
                same_axis = (x == n.x);
            }

            if (same_axis) {
                if (pos and base_cmp < othr_cmp and (othr_cmp - base_cmp) <= dist) {
                    out = i;
                    dist = (othr_cmp - base_cmp);
                } else if (!pos and base_cmp > othr_cmp and (base_cmp - othr_cmp) <= dist) {
                    out = i;
                    dist = (base_cmp - othr_cmp);
                }
            }
        }

        return out;
    }

    fn NodeLocateDirUncrossed(self: *Board, x: u16, y: u16, dir: Directions, pos: bool) ?usize {
        var out: ?usize = self.NodeLocateDir(x, y, dir, pos);

        if (out) {
            //TODO
        }

        return out;
    }

    /// Generate a New Puzzle to be solved
    pub fn Generate(self : *Board, settings : globals.DifficultySetting) void {
        //Create the nodes
        for (0..settings.Nodes) |i| {
            self.nodes = @truncate(i);

            var x: u16 = @intCast(raylib.GetRandomValue(0, settings.Square-1));
            var y: u16 = @intCast(raylib.GetRandomValue(0, settings.Square-1));
            while (self.NodeLocateCoord(x, y) != null) {
                x = @intCast(raylib.GetRandomValue(0, settings.Square-1));
                y = @intCast(raylib.GetRandomValue(0, settings.Square-1));
            }

            self.grid[i] = .{
                .id=x*3+y*5,
                .x=x,
                .y=y,
                .connections = std.EnumArray(Directions, ConnectionType).init(.{
                    .Right = ConnectionType.None,
                    .Down = ConnectionType.None,
                }),

                .user_connections = std.EnumArray(Directions, ConnectionType).init(.{
                    .Right = ConnectionType.None,
                    .Down = ConnectionType.None,
                }),
            };
        }

        self.nodes = settings.Nodes;
        self.square = settings.Square;

        var id_cnt: u16 = self.nodes;
        while (id_cnt > 1) { //TODO: This don't work
            const nidx: usize = @intCast(raylib.GetRandomValue(0, self.nodes));
            const n: *Node = &self.grid[nidx];

            const dir: Directions = @enumFromInt(raylib.GetRandomValue(0, 1));
            const pos: bool = (raylib.GetRandomValue(0, 1) == 1);

            const oidx: ?usize = self.NodeLocateDir(n.x, n.y, dir, pos);

            if (oidx) |oid| {
                const o: *Node = &self.grid[oid];
                if (o.id != n.id) {
                    //std.debug.print("Setting all {d} to {d}\n", o.id, n.id);
                    for (0..self.nodes) |i| {
                        if (self.grid[i].id == o.id) self.grid[i].id = n.id;
                    }

                    id_cnt -= 1;
                    o.bridges += 1;
                    n.bridges += 1;

                    if (pos) {
                        n.connections.set(dir, ConnectionType.Single);
                    } else {
                        o.connections.set(dir, ConnectionType.Single);
                    }
                }
            }
        }

        id_cnt = 0;
        var ids: [globals.MaxNodes]u16 = undefined;
        for (0..self.nodes) |i| {
            var unique: bool = true;
            for (0..id_cnt) |j| {
                if (ids[j] == self.grid[i].id) {
                    unique = false;
                    break;
                }
            }

            if (unique) {
                ids[id_cnt] = self.grid[i].id;
                id_cnt += 1;
            }
        }

        std.debug.print("{d}\n", .{id_cnt});
        //assert(id_cnt == 1);
    }

    /// Draw the Screen using Raylib
    pub fn Draw(self : *Board) void {
        const board_square: u32 = globals.window_square - globals.interface_margin;
        const node_space: u32 = board_square / @as(u32, self.square); //in pix
        const node_rd: u32 = node_space / 4; //radius, leave some room for bridges
        const brdg_sz: u32 = node_rd / 4;
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
            DrawLineDashed(rg_start, rg_end, 2, 2, raylib.GRAY);
            DrawLineDashed(cg_start, cg_end, 2, 2, raylib.GRAY);
        }

        for (0..self.nodes) |i| {
            const nd: *Node = &self.grid[i];

            const pix_x: c_int = @intCast(strt_x + nd.x * node_space - (brdg_sz/2));
            const pix_y: c_int = @intCast(strt_y + nd.y * node_space - (brdg_sz/2));

            if (nd.connections.get(Directions.Right) == ConnectionType.Single) {
                const oidx: usize = self.NodeLocateDir(nd.x, nd.y, Directions.Right, true) orelse unreachable;
                const dist = @abs(self.grid[oidx].x - nd.x);

                raylib.DrawRectangle(pix_x, pix_y, @intCast(node_space*dist), @intCast(brdg_sz), raylib.BLACK);
            } else if (nd.connections.get(Directions.Right) == ConnectionType.Double) {
                const oidx: usize = self.NodeLocateDir(nd.x, nd.y, Directions.Right, true) orelse unreachable;
                const dist = @abs(self.grid[oidx].x - nd.x);

                raylib.DrawRectangle(pix_x, pix_y+@as(c_int, @intCast(brdg_sz*2)), @intCast(node_space*dist), @intCast(brdg_sz), raylib.BLACK);
                raylib.DrawRectangle(pix_x, pix_y-@as(c_int, @intCast(brdg_sz*2)), @intCast(node_space*dist), @intCast(brdg_sz), raylib.BLACK);
            }

            if (nd.connections.get(Directions.Down) == ConnectionType.Single) {
                const oidx: usize = self.NodeLocateDir(nd.x, nd.y, Directions.Down, true) orelse unreachable;
                const dist = @abs(self.grid[oidx].y - nd.y);

                raylib.DrawRectangle(pix_x, pix_y, @intCast(brdg_sz), @intCast(node_space*dist), raylib.BLACK);
            } else if (nd.connections.get(Directions.Down) == ConnectionType.Double) {
                const oidx: usize = self.NodeLocateDir(nd.x, nd.y, Directions.Down, true) orelse unreachable;
                const dist = @abs(self.grid[oidx].y - nd.y);

                raylib.DrawRectangle(pix_x+@as(c_int, @intCast(brdg_sz*2)), pix_y, @intCast(brdg_sz), @intCast(node_space*dist), raylib.BLACK);
                raylib.DrawRectangle(pix_x-@as(c_int, @intCast(brdg_sz*2)), pix_y, @intCast(brdg_sz), @intCast(node_space*dist), raylib.BLACK);
            }

        }

        for (0..self.nodes) |i| {
            const nd: *Node = &self.grid[i];

            const pix_x: c_int = @intCast(strt_x + nd.x * node_space);
            const pix_y: c_int = @intCast(strt_y + nd.y * node_space);

            //Draw the Node
            raylib.DrawCircle(pix_x, pix_y, @floatFromInt(node_rd), raylib.BLACK);
            raylib.DrawCircle(pix_x, pix_y, @as(f32, @floatFromInt(node_rd)) * 0.9, globals.bg_color);

            //Draw the Bridge Count
            const buf = [_:0]u8{'0'+@as(u8, @truncate(nd.id))};
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
