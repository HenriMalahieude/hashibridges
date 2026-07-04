const std = @import("std");
const assert = std.debug.assert;

const globals = @import("globals.zig");
const raylib = globals.raylib;

//Complaint: Somehow this isn't located within raylib.h even though it's in there?
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

    const IdInfo = struct { //Complaint: Apparently zig cannot recognize anonymous structs that are the same....
        id: u16,
        cnt: u32,
    };

    grid : [globals.MaxNodes] Node = undefined,
    nodes : u16 = 0,
    max_nodes : u16 = 0,
    square: u16 = 0,
    double_chance: u16 = 0,

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
        for (0..self.nodes) |i| { //Complaint: I'd like to set the type of the capture variable, is that possible?
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
        self.square = settings.Square;
        self.double_chance = settings.DoubleChance;

        self.PlaceNodes(settings.Nodes); //create the nodes of interest
        self.max_nodes = settings.Nodes;

        self.DeleteUnreachableNodes(); //unreachable nodes should be reclaimed

        self.ConnectionStep(-1);
        //self.ResolveUnconnectedSubgraphs();
        //self.RebuildDeletedNodes();
        //self.Simplify();
        self.SaltDoubles();
        self.EvaluateBridgeCounts();
    }

    //Create the nodes, cannot overlap or be within 1 dist from each other
    pub fn PlaceNodes(self: *Board, am: u16) void {
        var i: usize = 0;
        var retries: u16 = 0;
        while (i < am) : (i += 1) {
            self.nodes = @truncate(i);
            const x: u16 = @intCast(raylib.GetRandomValue(0, self.square-1));
            const y: u16 = @intCast(raylib.GetRandomValue(0, self.square-1));
            if (self.NodeLocateCoord(x, y) != null) {
                if (i != 0) i -= 1;
                continue;
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

            if (retries < (am/2)) {
                var too_close: bool = false;
                for (0..self.nodes) |j| {
                    const n: *Node = &self.grid[j];
                    const diff_x = if (n.x > x) n.x - x else x - n.x;
                    const diff_y = if (n.y > y) n.y - y else y - n.y;
                    if ((diff_y <= globals.min_node_dist and diff_x == 0)
                        or (diff_x <= globals.min_node_dist and diff_y == 0)) {
                        too_close = true;
                        break;
                    }

                }

                if (too_close) {
                    //Manually Locate a Solid Location
                    if (self.nodes >= (am / 2)) {
                        retries += 1; //we may have exhausted all possible places
                    }
                    i -= 1;
                    continue;
                }
            } else {
                //std.debug.print("Reached maximum retries {d}\n", .{i});
                retries = 0;
            }
            self.nodes += 1; //NOTE: Redundant until we're on the last iteration
        }

        std.debug.print("Placed {} nodes!\n", .{self.nodes});
    }

    pub fn DeleteUnreachableNodes(self: *Board) void {
        //Nuke all nodes w/o possible targets
        var i: i32 = 0;
        while (i < self.nodes) : (i += 1) {
            const up = self.NodeLocateDir(@intCast(i), Direction.Down, false);
            const right = self.NodeLocateDir(@intCast(i), Direction.Right, true);
            const down = self.NodeLocateDir(@intCast(i), Direction.Down, true);
            const left = self.NodeLocateDir(@intCast(i), Direction.Right, false);

            if (up == null and right == null and down == null and left == null) {
                self.DeleteNode(@intCast(i));
                i -= 1;
            }
        }
        std.debug.print("Pruned to {} nodes!\n", .{self.nodes});
    }

    pub fn DeleteNode(self: *Board, idx: usize) void {
        for (idx..self.nodes) |i| {
            if (i+1 >= self.nodes) break; //nothing left to copy
            self.grid[i] = self.grid[i+1];
        }

        self.nodes -= 1;
    }

    pub fn DeleteNodesById(self: *Board, id: u16) void {
        var i: i32 = 0;
        while (i < self.nodes) : (i += 1) {
            const n: *Node = &self.grid[@intCast(i)];
            if (n.id == id) {
                self.DeleteNode(@intCast(i));
                i -= 1;
            }
        }
        std.debug.print("Down to {} nodes!\n", .{self.nodes});
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
            var ids: [globals.MaxNodes]IdInfo = undefined;
            const id_cnt: usize = self.CalculateRemainingIds(&ids);

            //std.debug.print("\n", .{});
            //for (0..id_cnt) |i| {
            //    std.debug.print("Id: {d}, Cnt: {d}\n", .{ids[i].id, ids[i].cnt});
            //}

            //If we should've been done
            if (prv_id_cnt == id_cnt) { //we've reached an impass
                //std.debug.print("Previous id count is equal to current!\n", .{});
                if (distance_max != self.square) {
                    distance_max = self.square; //expand the max distance
                    //std.debug.print("Expanding max distance!\n", .{});
                    continue;
                } else { //max distance wasn't the issue
                    break;
                }
            }

            prv_id_cnt = id_cnt;
            if (id_cnt <= 1) break;
        }
    }

    pub fn CalculateRemainingIds(self: *Board, ids: *[globals.MaxNodes]IdInfo) usize {
        var id_cnt: usize = 0;
        //var ids: [globals.MaxNodes]struct{id:u16, cnt:u32} = undefined;
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

        return id_cnt;
    }

    //TODO: Options
    //      1. If spare nodes, attempt to add some that are far enough away from others
    //      3. If failed, delete the graph

    pub fn ResolveUnconnectedSubgraphs(self: *Board) void {
        var ids: [globals.MaxNodes]IdInfo = undefined;
        var id_cnt = self.CalculateRemainingIds(&ids);
        assert(id_cnt < globals.MaxNodes);

        //Identify primary island
        var big_id = ids[0].id;
        var big_cnt = ids[0].cnt;
        for (1..id_cnt) |i| {
            if (ids[i].cnt >= big_cnt) {
                big_id = ids[i].id; //Complaint: No destructuring structs?
                big_cnt = ids[i].cnt;
            }
        }

        //Begin by removing too small subgraphs
        for (0..id_cnt) |i| if (ids[i].cnt <= @max((self.max_nodes / 10), 2)) self.DeleteNodesById(ids[i].id);
        //Complaint: I got weird errors on 1-line for loops before, but now not?

        id_cnt = self.CalculateRemainingIds(&ids);
        //Add nodes if we have room
        if (id_cnt > 1) {
            std.debug.print("Found {} ids!\n", .{id_cnt});
            if (self.nodes < self.max_nodes) {
                std.debug.print("Got room to reconnect!\n", .{});
                for (0..id_cnt) |i| {
                    if (self.nodes >= self.max_nodes) break;
                    if (big_id == ids[i].id) continue;

                    var reconnected: bool = false;
                    for (0..self.nodes) |ni| {
                        if (reconnected) break;

                        const n: *Node = &self.grid[ni];
                        if (n.id != ids[i].id) continue;

                        const conRight = (n.connections.get(.Right) != .None);
                        const conDown = (n.connections.get(.Down) != .None);
                        const conLeft = (self.NodeLocateDirUncrossed(ni, .Right, false) != null);
                        const conUp = (self.NodeLocateDirUncrossed(ni, .Down, false) != null);

                        var node_cand: *Node = &self.grid[self.nodes];
                        node_cand.id = n.id;
                        node_cand.x = n.x;
                        node_cand.y = n.y;
                        node_cand.bridges = 99; //TODO: debugging
                        node_cand.connections.set(.Right, .None);
                        node_cand.connections.set(.Down, .None);
                        self.nodes += 1;

                        //Go through available axi, and attempt to reconnect to biggest subgraph
                        loop_node_axi: for ([_]struct{valid:bool, start:u16, end:i16, horz:bool, pos:bool}{ //Complaint: I think this labelling thing could be better
                            .{.valid=!conRight, .start=n.x+1, .end=@intCast(self.square),       .horz=true, .pos=true}, //Complaint: cannot store ((n.x+1) .. self.square)
                            .{.valid=!conLeft,  .start=0,     .end=@as(i16, @intCast(n.x)) - 1, .horz=true, .pos=false},
                            .{.valid=!conDown,  .start=n.y+1, .end=@intCast(self.square),       .horz=false, .pos=true},
                            .{.valid=!conUp,    .start=0,     .end=@as(i16, @intCast(n.y)) - 1, .horz=false, .pos=false},
                        }) |args| {
                            if (reconnected) break;
                            if (!args.valid) continue;

                            if (args.end < 0 or args.start == args.end or args.start > self.square) break; //not a valid range

                            //std.debug.print("{} to {}\n", .{args.start, args.end}); //Complaint: Cannot do reverse ranges, especially for 0
                            for (args.start .. @intCast(args.end)) |p| { //Complaint: Can I change the type of the range?
                                node_cand.x = if (args.horz) @truncate(p) else n.x; //move it along the chosen axis
                                node_cand.y = if (args.horz) n.y else @truncate(p);

                                //Do we still connect back
                                const tmp = self.NodeLocateDirUncrossed(ni, if (args.horz) .Right else .Down, args.pos);
                                if (tmp == null or tmp.? != self.nodes-1) {
                                    if (args.pos) { break; }
                                    else continue; //Complaint: cannot do followup else's w/o curlies {}
                                }

                                for ([_]struct{dir:Direction, pos:bool}{
                                    .{.dir=.Right, .pos=true},
                                    .{.dir=.Right, .pos=false},
                                    .{.dir=.Down, .pos=true},
                                    .{.dir=.Down, .pos=false},
                                }) |arg2| {
                                    const oth = self.NodeLocateDirUncrossed(self.nodes-1, arg2.dir, arg2.pos);
                                    //we've located a valid spot to connect the subgraphs and it isn't already overtaken
                                    if (oth != null and self.grid[oth.?].id == big_id and self.grid[oth.?].connections.get(arg2.dir) == .None) {
                                        //Connect subgraph to join point
                                        if (args.pos) {
                                            n.connections.set(if (args.horz) .Right else .Down, .Single);
                                        } else {
                                            node_cand.connections.set(if (args.horz) .Right else .Down, .Single);
                                        }

                                        std.debug.print("\nBased off {}, {}\n", .{n.x, n.y});
                                        std.debug.print("{} {} {} {}\n", .{!conRight, !conDown, !conLeft, !conUp});
                                        //Did we actually cut a bridge? If so, disregard new connection
                                        //If we are cutting a bridge, inherit the bridge from target
                                        const inh_dir: Direction = (if (args.horz) .Down else .Right);
                                        const inh = self.NodeLocateDirUncrossed(self.nodes-1, inh_dir, false);
                                        if (inh != null and self.grid[inh.?].id != big_id) break :loop_node_axi; //crossing ourselves, or someone else

                                        if (inh != null and self.grid[inh.?].connections.get(inh_dir) != .None) {
                                            std.debug.print("Inheritted @ ({}, {})\n", .{node_cand.x, node_cand.y});
                                            node_cand.connections.set(inh_dir, self.grid[inh.?].connections.get(inh_dir));
                                        } else { //Otherwise do connect
                                            std.debug.print("Connected {s} {s} @ ({}, {})\n", .{
                                                if (arg2.dir == .Right) "Right" else "Down",
                                                if (arg2.pos) "True" else "False",
                                                node_cand.x,
                                                node_cand.y
                                            });

                                            if (arg2.pos) {
                                                node_cand.connections.set(arg2.dir, .Single);
                                            } else {
                                                self.grid[oth.?].connections.set(arg2.dir, .Single);
                                            }
                                        }

                                        //self.GridApplyIdToId(n.id, big_id);
                                        reconnected = true;
                                        break :loop_node_axi; //Complaint: better error message when missing colon
                                    }
                                }
                            }
                        }

                        if (!reconnected) self.nodes -= 1;
                    }
                    if (!reconnected) {
                        std.debug.print("Failed to reconnect this subgraph, deleting!\n", .{});
                        self.DeleteNodesById(ids[i].id);
                    }
                }
            } else { //no room to add anything
                std.debug.print("Failed to connect due to lacking materials\n", .{});
                for (0..id_cnt) |i| if (ids[i].id != big_id) self.DeleteNodesById(ids[i].id); //just delete the remaining
            }
        }
    }

    //TODO:
    //      1. Nodes should extend to right before a crossing edge

    //pub fn SimplifyGraph(self: *Board) void { }

    //Randomly select
    pub fn SaltDoubles(self: *Board) void {
        for (0..self.nodes) |i| {
            const n: *Node = &self.grid[i];
            if (n.connections.get(.Right) != .None) {
                const value = raylib.GetRandomValue(0, 100);
                if (value < self.double_chance) {
                    n.connections.set(.Right, .Double);
                }
            }

            if (n.connections.get(.Down) != .None) {
                const value = raylib.GetRandomValue(0, 100);
                if (value < self.double_chance) {
                    n.connections.set(.Down, .Double);
                }
            }
        }
    }

    pub fn EvaluateBridgeCounts(self: *Board) void {
        for (0..self.nodes) |i| {
            const n: *Node = &self.grid[i];

            const r = n.connections.get(.Right);
            const d = n.connections.get(.Down);

            if (r != .None) {
                n.bridges += @intFromEnum(r);
                const rn = self.NodeLocateDir(i, .Right, true).?;
                self.grid[rn].bridges += @intFromEnum(r);
            }

            if (d != .None) {
                n.bridges += @intFromEnum(d);
                const dn = self.NodeLocateDir(i, .Down, true).?;
                self.grid[dn].bridges += @intFromEnum(d);
            }
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

                raylib.DrawRectangle(pix_x, pix_y+@as(c_int, @intCast(brdg_sz*1)), @intCast(node_space*dist), @intCast(brdg_sz), raylib.BLACK);
                raylib.DrawRectangle(pix_x, pix_y-@as(c_int, @intCast(brdg_sz*1)), @intCast(node_space*dist), @intCast(brdg_sz), raylib.BLACK);
            }

            if (nd.connections.get(Direction.Down) == ConnectionType.Single) {
                const oidx: usize = self.NodeLocateDir(i, Direction.Down, true) orelse unreachable;
                const dist = @abs(self.grid[oidx].y - nd.y);

                raylib.DrawRectangle(pix_x, pix_y, @intCast(brdg_sz), @intCast(node_space*dist), raylib.BLACK);
            } else if (nd.connections.get(Direction.Down) == ConnectionType.Double) {
                const oidx: usize = self.NodeLocateDir(i, Direction.Down, true) orelse unreachable;
                const dist = @abs(self.grid[oidx].y - nd.y);

                raylib.DrawRectangle(pix_x+@as(c_int, @intCast(brdg_sz*1)), pix_y, @intCast(brdg_sz), @intCast(node_space*dist), raylib.BLACK);
                raylib.DrawRectangle(pix_x-@as(c_int, @intCast(brdg_sz*1)), pix_y, @intCast(brdg_sz), @intCast(node_space*dist), raylib.BLACK);
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
            const buf = [_:0]u8{'0'+@as(u8, @truncate(nd.id))}; //Complaint: I'm not a huge fan of repeatedly stacked @ for casting
            const txtPixSz = raylib.MeasureTextEx(raylib.GetFontDefault(), &buf, @as(f32, @floatFromInt(text_sz)), 0);
            raylib.DrawText(&buf, pix_x - @as(u16, @intFromFloat(txtPixSz.x/2)), pix_y - @as(u16, @intFromFloat(txtPixSz.y/2)), @intCast(text_sz), globals.tx_color);

        }
    }

    /// Interact with the board using Raylib
    pub fn Interact(self : *Board) void {
        _ = self;
    }
};
