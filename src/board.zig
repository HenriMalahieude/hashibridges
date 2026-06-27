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
    const Direction = enum { Right, Down }; //no need to store duplicate information

    const Node = struct {
        id: u16 = 0,
        x : u16 = 0,
        y : u16 = 0,
        bridges: u8 = 0,
        connections : std.EnumArray(Direction, ConnectionType) = undefined,
        user_connections : std.EnumArray(Direction, ConnectionType) = undefined,
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

    fn NodeLocateDir(self: *Board, idx: usize, dir: Direction, pos: bool) ?usize{
        const base = self.grid[idx];

        var out: ?usize = null;
        var dist: usize = self.square + 1;
        for (0..self.nodes) |i| {
            if ( i == idx ) { continue; }
            const n = &self.grid[i];

            var base_cmp: u16 = base.x;
            var othr_cmp: u16 = n.x;
            var same_axis: bool = (base.y == n.y);
            if (dir == Direction.Down) {
                base_cmp = base.y;
                othr_cmp = n.y;
                same_axis = (base.x == n.x);
            }

            if (same_axis) {
                if (pos and base_cmp < othr_cmp and (othr_cmp - base_cmp) < dist) {
                    out = i;
                    dist = (othr_cmp - base_cmp);
                } else if (!pos and base_cmp > othr_cmp and (base_cmp - othr_cmp) < dist) {
                    out = i;
                    dist = (base_cmp - othr_cmp);
                }
            }
        }

        return out;
    }

    fn NodeLocateDirUncrossed(self: *Board, idx: usize, dir: Direction, pos: bool) ?usize {
        const m_jdx: ?usize = self.NodeLocateDir(idx, dir, pos);

        if (m_jdx) |jdx| { //we've located that it does have a possible ending
            var bse: *Node = &self.grid[idx];
            var end: *Node = &self.grid[jdx];
            if (!pos) {
                bse = end;
                end = &self.grid[idx];
            }

            //Pruning time
            for (0..self.nodes) |i| {
                const n: *Node = &self.grid[i];

                //Check the connections that are between the two AND only need to check 1 node
                if (dir == Direction.Down and n.y > bse.y and n.y < end.y and n.x < bse.x) {
                    if (n.connections.get(Direction.Right) != ConnectionType.None) { //There exists a connection, but does it cross us?
                        const m_ldx: ?usize = self.NodeLocateDir(i, Direction.Right, true);
                        if (m_ldx != null and self.grid[m_ldx.?].x > bse.x) return null;
                    }
                } else if (n.x > bse.x and n.x < end.x and n.y < bse.y) {
                    if (n.connections.get(Direction.Down) != ConnectionType.None) {
                        const m_ldx: ?usize = self.NodeLocateDir(i, Direction.Down, true);
                        if (m_ldx != null and self.grid[m_ldx.?].y > bse.y) return null;

                    }
                }
            }
        }

        return m_jdx;
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
                .id=@truncate(i),
                .x=x,
                .y=y,
                .connections = std.EnumArray(Direction, ConnectionType).init(.{
                    .Right = ConnectionType.None,
                    .Down = ConnectionType.None,
                }),

                .user_connections = std.EnumArray(Direction, ConnectionType).init(.{
                    .Right = ConnectionType.None,
                    .Down = ConnectionType.None,
                }),
            };
        }

        self.nodes = settings.Nodes;
        self.square = settings.Square;

        //Nuke all nodes w/o possible targets
        var i: usize = 0;
        while (i < self.nodes) : (i += 1) {
            const up = self.NodeLocateDir(i, Direction.Down, false);
            const right = self.NodeLocateDir(i, Direction.Right, true);
            const down = self.NodeLocateDir(i, Direction.Down, true);
            const left = self.NodeLocateDir(i, Direction.Right, false);

            if (up == null and right == null and down == null and left == null) {
                self.DeleteNode(i);
                if (i > 0) i -= 1;
            }
        }

        //self.ConnectionStep(-1);
    }

    pub fn DeleteNode(self: *Board, idx: usize) void {
        for (idx..self.nodes) |i| {
            if (i+1 >= self.nodes) break; //nothing left to copy
            self.grid[i] = self.grid[i+1];
        }

        self.nodes -= 1;
    }

    pub fn DeleteNodesById(self: *Board, id: u16) void {
        var i: usize = 0;
        while (i < self.nodes) : (i += 1) {
            const n: *Node = &self.grid[i];
            if (n.id == id) {
                self.DeleteNode(i);
                if (i > 0) i -= 1;
            }
        }
    }

    pub fn GridApplyIdToId(self: *Board, old_id: u16, new_id: u16) void {
        if (old_id == new_id) return;

        for (0..self.nodes) |i| {
            const n: *Node = &self.grid[i];

            if (n.id == old_id) {
                n.id = new_id;
            }
        }
    }

    // An Implementation of Kruskal's Minimum Spanning Tree Algorithm, formatted for Maze Generation, then reformatted for Hashi
    pub fn ConnectionStep(self: *Board, steps_max: i16) void {
        var distance_max: u16 = (self.square * 1) / 2; //begin with local subgraphs
        var prv_id_cnt: usize = 0;
        var steps: u16 = 0;

        while (true) {
            if (steps_max > 0) {
                if (steps >= steps_max) break;
                steps += 1;
            }

            //Connect all nodes normally
            for (0..self.nodes) |i| { //no need to randomly select node, each node alr has random position
                const n: *Node = &self.grid[i];
                var right: ?usize = self.NodeLocateDirUncrossed(i, Direction.Right, true);
                var down: ?usize = self.NodeLocateDirUncrossed(i, Direction.Down, true);

                //Debug
                //if (distance_max == self.square) {
                //    std.debug.print("Node [{d}] ({d}, {d}) has neighbors:\n", .{i, n.x, n.y});

                //    std.debug.print("\t{d}\n", .{right orelse self.NodeLocateDir(i, Direction.Right, true) orelse 404});
                //    std.debug.print("\t{d}\n", .{down orelse self.NodeLocateDir(i, Direction.Down, true) orelse 404});
                //}

                if (right != null and self.grid[right.?].id == n.id) right = null; //don't connect to same subgraph
                if (down != null and self.grid[down.?].id == n.id) down = null;
                if (right != null and @abs(self.grid[right.?].x - n.x) > distance_max) right = null; //distance check
                if (down != null and @abs(self.grid[down.?].x - n.x) > distance_max) down = null;
                if (right == null and down == null) continue; //node irrelevant


                const horz: bool = (raylib.GetRandomValue(0, 1) == 1);
                if ((horz or down == null) and right != null) {
                    n.connections.set(Direction.Right, ConnectionType.Single);
                    self.GridApplyIdToId(self.grid[right.?].id, n.id);
                } else if (down != null) {
                    n.connections.set(Direction.Down, ConnectionType.Single);
                    self.GridApplyIdToId(self.grid[down.?].id, n.id);
                }
            }

            //Are we done?
            std.debug.print("\t", .{});
            var id_cnt: usize = 0;
            var ids: [globals.MaxNodes]struct{id:u16, cnt:u32} = undefined;
            for (0..self.nodes) |i| {
                var unique: bool = true;
                for (0..id_cnt) |j| {
                    if (ids[j].id == self.grid[i].id) {
                        ids[j].cnt += 1;
                        unique = false;
                        break;
                    }
                }

                if (unique) {
                    ids[id_cnt].id = self.grid[i].id;
                    ids[id_cnt].cnt = 1;
                    id_cnt += 1;
                }
            }

            std.debug.print("\n", .{});
            for (0..id_cnt) |i| {
                std.debug.print("Id: {d}, Cnt: {d}\n", .{ids[i].id, ids[i].cnt});
            }

            //If we should've been done
            if (prv_id_cnt == id_cnt) { //we've reached an impass due to either a distance issue or blocking edge
                std.debug.print("Previous id count is equal to current!\n", .{});
                if (distance_max != self.square) {
                    distance_max = self.square; //expand the max distance
                    //std.debug.print("Expanding max distance!\n", .{});
                    continue;
                } else { //max distance wasn't the issue
                    var dealt_with: bool = false;
                    for (0..id_cnt) |i| {
                        if (ids[i].cnt <= @max((self.nodes / 5), 2)) { //delete any subgraph with less than 20% of nodes
                            self.DeleteNodesById(ids[i].id);
                            std.debug.print("Deleting\n", .{});
                            dealt_with = true; //one step is dealt with
                            break;
                        }
                    }

                    if (dealt_with) continue;
                    std.debug.print("Not dealt with!\n", .{});

                    //TODO: Three Options
                    //      1. Remove a blocking edge
                    //      2. Remove the island <= easiest to do
                    //      3. Regenerate off of the main island
                    break;
                }
            }

            prv_id_cnt = id_cnt;
            if (id_cnt <= 1) break;
        }
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

            if (nd.connections.get(Direction.Right) == ConnectionType.Single) {
                const oidx: usize = self.NodeLocateDir(i, Direction.Right, true) orelse unreachable;
                const dist = @abs(self.grid[oidx].x - nd.x);

                raylib.DrawRectangle(pix_x, pix_y, @intCast(node_space*dist), @intCast(brdg_sz), raylib.BLACK);
            } else if (nd.connections.get(Direction.Right) == ConnectionType.Double) {
                const oidx: usize = self.NodeLocateDir(i, Direction.Right, true) orelse unreachable;
                const dist = @abs(self.grid[oidx].x - nd.x);

                raylib.DrawRectangle(pix_x, pix_y+@as(c_int, @intCast(brdg_sz*2)), @intCast(node_space*dist), @intCast(brdg_sz), raylib.BLACK);
                raylib.DrawRectangle(pix_x, pix_y-@as(c_int, @intCast(brdg_sz*2)), @intCast(node_space*dist), @intCast(brdg_sz), raylib.BLACK);
            }

            if (nd.connections.get(Direction.Down) == ConnectionType.Single) {
                const oidx: usize = self.NodeLocateDir(i, Direction.Down, true) orelse unreachable;
                const dist = @abs(self.grid[oidx].y - nd.y);

                raylib.DrawRectangle(pix_x, pix_y, @intCast(brdg_sz), @intCast(node_space*dist), raylib.BLACK);
            } else if (nd.connections.get(Direction.Down) == ConnectionType.Double) {
                const oidx: usize = self.NodeLocateDir(i, Direction.Down, true) orelse unreachable;
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
