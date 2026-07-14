const std = @import("std");
const assert = std.debug.assert;

const globals = @import("globals.zig");
const raylib = globals.raylib;

//Complaint: Somehow this isn't located within raylib.h even though it's in there?
//pub extern "c" fn DrawLineDashed(a: raylib.Vector2, b: raylib.Vector2, c: c_int, d: c_int, e: raylib.Color) void;

///Pixel Size for Drawing
const board_square: u32 = globals.window_square - globals.interface_margin;

const ConnectionType = enum(u8) { None=0, Single=1, Double=2 };
const GameState = enum { Ungenerated, Running, Complete };
const Direction = enum { Right, Down }; //no need to store duplicate information

const Node = struct {
    id: u16 = 0,
    x : u16 = 0,
    y : u16 = 0,
    bridges: u8 = 0,
    user_bridges: u8 = 0,
    connections : std.EnumArray(Direction, ConnectionType) = undefined,
    user_connections : std.EnumArray(Direction, ConnectionType) = undefined,
};

const IdInfo = struct { //Complaint: Apparently zig cannot recognize anonymous structs that are the same....
    id: u16,
    cnt: u32,
};

/// Represents the game state
pub const Board = struct {

    //Pixel sizes
    node_space: u32,
    node_rd: u32,
    brdg_sz: u32,
    text_sz: u32,

    //Center of the start locations in pixels
    strt_x: u32,
    strt_y: u32,

    //Variables
    grid : [globals.MaxNodes] Node = undefined,
    nodes : u16 = 0,
    max_nodes : u16 = 0,
    square: u16 = 0,
    double_chance: u16 = 0,

    state : GameState = GameState.Ungenerated,

    pub fn StaticCopyTo(from: *Board, to: *Board) void {
        to.nodes = from.nodes;
        to.max_nodes = from.nodes;
        to.square = from.square;
        to.double_chance = from.double_chance;
        to.state = from.state;

        for (0..from.nodes) |i| to.grid[i] = from.grid[i];
    }

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
    pub fn Generate(self : *Board, settings : globals.DifficultySetting, other: ?*Board) void {
        self.node_space = board_square / @as(u32, settings.Square); //in pix
        self.node_rd = self.node_space / 4; //radius, leave some room for bridges
        self.brdg_sz = self.node_rd / 4;
        self.text_sz = self.node_space / 5;

        //Center of the start locations in pixels
        self.strt_x = (globals.interface_margin/2) + (self.node_space/2);
        self.strt_y = (globals.interface_margin/2) + (self.node_space/2);
        //std.debug.print("Board Sqr: {}, Node Rad: {}, Bridge Sz: {}, Txt Sz: {}, Strt ({}, {})\n", .{board_square, self.node_rd, self.brdg_sz, self.text_sz, self.strt_x, self.strt_y});

        //Relevant info
        self.nodes = 0;
        self.square = settings.Square;
        self.double_chance = settings.DoubleChance;
        self.max_nodes = settings.Nodes;

        //This was caught by zig, even if by accident actually really goated
        //Zero Initialization for everything that we couldn't initialize in the defaults
        for (0..self.max_nodes) |i| {
            const n: *Node = &self.grid[i];
            n.connections.set(.Right, .None);
            n.connections.set(.Down, .None);

            n.user_connections.set(.Right, .None);
            n.user_connections.set(.Down, .None);
        }

        while (self.nodes == 0) { //it can happen sometimes
            self.PlaceNodes(settings.Nodes-1); //create the nodes of interest, but leave room for connections

            self.DeleteUnreachableNodes(); //unreachable nodes should be reclaimed

            self.ConnectionStep(-1);

            self.ResolveUnconnectedSubgraphs();
        }

        if (other != null) self.StaticCopyTo(other.?);

        self.RebuildDeletedNodes();
        //self.Simplify(); //TODO: Not really necessary
        self.SaltDoubles();
        self.EvaluateBridgeCounts(false);
        self.EvaluateBridgeCounts(true);
    }

    //test "TODO" {
    //    for (0..100) |_| {
    //        self.Generate();

    //        for (0..self.nodes) |i| {
    //            const n: *Node = &self.grid[i];
    //            if (n.x >= self.square or n.y >= self.square) std.debug.print("? Node ({}, {}) outside of bounds ?", .{n.x, n.y});
    //            break;
    //        }

    //        //if (self.nodes != self.max_nodes) std.debug.print("Grid was not full\n", .{})
    //        //else std.debug.print("Grid is full!\n", .{});

    //        var ids: [globals.MaxNodes]IdInfo = undefined;
    //        const id_cnt = self.CalculateRemainingIds(&ids);
    //        if (id_cnt != 1) {
    //            std.debug.print("Nodes: {}\n", .{self.nodes});
    //            std.debug.print("Located a case of multi ids remaining after resolution step! (i={})\n", .{outer});
    //            for (ids[0..id_cnt]) |idinfo| std.debug.print("\t{} @ x{}\n", .{idinfo.id, idinfo.cnt});
    //            break;
    //        }
    //    }
        //if (outer == 99) std.debug.print("Everything fine\n", .{});
    //};

    //Create the nodes, cannot overlap or be within 1 dist from each other
    pub fn PlaceNodes(self: *Board, am: u16) void {
        var i: usize = 0;
        var retries: u16 = 0;
        while (i < am) : (i += 1) {
            self.nodes = @truncate(i);
            const x: u16 = @intCast(raylib.getRandomValue(0, self.square-1));
            const y: u16 = @intCast(raylib.getRandomValue(0, self.square-1));
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
                .bridges = 0,
                .user_bridges = 0,
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

        //std.debug.print("Placed {} nodes!\n", .{self.nodes});
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
        //std.debug.print("Pruned to {} nodes!\n", .{self.nodes});
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
        //std.debug.print("Down to {} nodes!\n", .{self.nodes});
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


                const horz: bool = (raylib.getRandomValue(0, 1) == 1);
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
            //std.debug.print("Found {} ids!\n", .{id_cnt});
            if (self.nodes < self.max_nodes) {
                //std.debug.print("Got room to reconnect!\n", .{});
                for (0..id_cnt) |i| {
                    if (big_id == ids[i].id) continue;
                    //std.debug.print("Attempting to reconnect {}\n", .{ids[i].id});
                    if (self.nodes >= self.max_nodes) {
                        //std.debug.print("Maximum nodes used, deleting self!\n", .{});
                        self.DeleteNodesById(ids[i].id);
                        continue;
                    }

                    var reconnected: bool = false;
                    for (0..self.nodes) |ni| {
                        if (reconnected) break;

                        const n: *Node = &self.grid[ni];
                        if (n.id != ids[i].id) continue;

                        const conRight = (n.connections.get(.Right) != .None);
                        const conDown = (n.connections.get(.Down) != .None);
                        const conLeft = bL: { //Complaint: I'd like to not have to label this tbh
                            const leftNode = self.NodeLocateDirUncrossed(i, .Right, false) orelse break :bL false;
                            if (self.grid[leftNode].connections.get(.Right) != .None) break :bL true;
                            break :bL false;
                        };
                        const conUp = bU: {
                            const upNode = self.NodeLocateDirUncrossed(i, .Down, false) orelse break :bU false;
                            if (self.grid[upNode].connections.get(.Down) != .None) break :bU true;
                            break :bU false;
                        };

                        var node_cand: *Node = &self.grid[self.nodes];
                        node_cand.id = n.id;
                        node_cand.x = n.x;
                        node_cand.y = n.y;
                        node_cand.bridges = 0;
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
                                        //std.debug.print("\nBased off {}, {}\n", .{n.x, n.y});
                                        //std.debug.print("{} {} {} {}\n", .{!conRight, !conDown, !conLeft, !conUp});
                                        //Did we actually cut a bridge? If so, disregard new connection
                                        //If we are cutting a bridge, inherit the bridge from target
                                        const inh_dir: Direction = (if (args.horz) .Down else .Right);
                                        const inh = self.NodeLocateDirUncrossed(self.nodes-1, inh_dir, false);
                                        if (inh != null and self.grid[inh.?].id != big_id) break :loop_node_axi; //crossing ourselves, or someone else

                                        //Connect subgraph to join point
                                        if (args.pos) {
                                            n.connections.set(if (args.horz) .Right else .Down, .Single);
                                        } else {
                                            node_cand.connections.set(if (args.horz) .Right else .Down, .Single);
                                        }

                                        if (inh != null and self.grid[inh.?].connections.get(inh_dir) != .None) {
                                            //std.debug.print("Inheritted @ ({}, {})\n", .{node_cand.x, node_cand.y});
                                            node_cand.connections.set(inh_dir, self.grid[inh.?].connections.get(inh_dir));
                                        } else { //Otherwise do connect
                                            //std.debug.print("Connected {s} {s} @ ({}, {})\n", .{
                                            //    if (arg2.dir == .Right) "Right" else "Down",
                                            //    if (arg2.pos) "True" else "False",
                                            //    node_cand.x,
                                            //    node_cand.y
                                            //});

                                            if (arg2.pos) {
                                                node_cand.connections.set(arg2.dir, .Single);
                                            } else {
                                                self.grid[oth.?].connections.set(arg2.dir, .Single);
                                            }
                                        }

                                        self.GridApplyIdToId(n.id, big_id);
                                        reconnected = true;
                                        break :loop_node_axi; //Complaint: better error message when missing colon
                                    }
                                }
                            }
                        }

                        if (!reconnected) self.nodes -= 1;
                    }
                    if (!reconnected) {
                        //std.debug.print("Failed to reconnect this subgraph, deleting!\n", .{});
                        self.DeleteNodesById(ids[i].id);
                    }
                }
            } else { //no room to add anything
                //std.debug.print("Failed to connect due to lacking materials\n", .{});
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
                const value = raylib.getRandomValue(0, 100);
                if (value < self.double_chance) {
                    n.connections.set(.Right, .Double);
                }
            }

            if (n.connections.get(.Down) != .None) {
                const value = raylib.getRandomValue(0, 100);
                if (value < self.double_chance) {
                    n.connections.set(.Down, .Double);
                }
            }
        }
    }

    pub fn EvaluateBridgeCounts(self: *Board, user: bool) void {
        for (0..self.nodes) |i| {
            if (!user) self.grid[i].bridges = 0
            else self.grid[i].user_bridges = 0;
        }

        for (0..self.nodes) |i| {
            const n: *Node = &self.grid[i];

            var r = n.connections.get(.Right);
            var d = n.connections.get(.Down);
            if (user) {
                r = n.user_connections.get(.Right);
                d = n.user_connections.get(.Down);
            }

            if (r != .None) {
                if (!user) n.bridges += @intFromEnum(r)
                else n.user_bridges += @intFromEnum(r);
                const rn = self.NodeLocateDir(i, .Right, true).?;
                if (!user) self.grid[rn].bridges += @intFromEnum(r)
                else self.grid[rn].user_bridges += @intFromEnum(r);
            }

            if (d != .None) {
                if (!user) n.bridges += @intFromEnum(d)
                else n.user_bridges += @intFromEnum(d);
                const dn = self.NodeLocateDir(i, .Down, true).?;
                if (!user) self.grid[dn].bridges += @intFromEnum(d)
                else self.grid[dn].user_bridges += @intFromEnum(d);
            }
        }
    }

    //Assumes we've already connected everything
    fn RebuildDeletedNodes(self: *Board) void {
        while (self.nodes < self.max_nodes) {
            var inserted: bool = false;

            loop_insert_retry:
                for (0..self.nodes) |i| {
                //const i: usize = @intCast(raylib.GetRandomValue(0, @intCast(self.nodes-1)));
                const n: *Node = &self.grid[i];

                const conRight = (n.connections.get(.Right) != .None);
                const conDown = (n.connections.get(.Down) != .None);
                const conLeft = bL: { //Complaint: I'd like to not have to label this tbh
                    const leftNode = self.NodeLocateDirUncrossed(i, .Right, false) orelse break :bL false;
                    if (self.grid[leftNode].connections.get(.Right) != .None) break :bL true;
                    break :bL false;
                };
                const conUp = bU: {
                    const upNode = self.NodeLocateDirUncrossed(i, .Down, false) orelse break :bU false;
                    if (self.grid[upNode].connections.get(.Down) != .None) break :bU true;
                    break :bU false;
                };

                if (!conRight and !conDown and !conLeft and !conUp) {
                    //std.debug.print("({}, {}) could not be built off!\n", .{n.x, n.y});
                    continue :loop_insert_retry;
                }

                const node_cand: *Node = &self.grid[self.nodes];
                node_cand.id = n.id;
                node_cand.x = n.x;
                node_cand.y = n.x;
                node_cand.bridges = 0;
                node_cand.connections.set(.Right, .None);
                node_cand.connections.set(.Down, .None);
                self.nodes += 1; //willed into existence

                for ([_]struct{valid:bool, start:u16, end: i16, horz: bool, pos: bool} {//Complaint: do I inline this or not? I do this to avoid repetition, but idk
                    .{.valid=!conRight, .start=(n.x+globals.min_node_dist), .end=@intCast(self.square), .horz=true, .pos=true},
                    .{.valid=!conDown, .start=(n.y+globals.min_node_dist), .end=@intCast(self.square), .horz=false, .pos=true},
                    .{.valid=!conLeft, .start=0, .end=@as(i16, @intCast(n.x))-globals.min_node_dist, .horz=true, .pos=false},
                    .{.valid=!conUp, .start=0, .end=@as(i16, @intCast(n.y))-globals.min_node_dist, .horz=false, .pos=false},
                }) |args| {
                    //std.debug.print("Axi Testing: {}, {}, {} -> {}\n", .{args.horz, args.pos, args.start, args.end});
                    if (!args.valid) continue;
                    if (args.start >= self.square or args.end < 0 or args.start > args.end) continue;

                    loop_insert_axi: for (args.start .. @intCast(args.end)) |p| {
                        node_cand.x = if (args.horz) @truncate(p) else n.x;
                        node_cand.y = if (args.horz) n.y else @truncate(p);

                        //Boundary check
                        for (0..(self.nodes-1)) |j| {
                            const tn: *Node = &self.grid[j];
                            const diff_x = if (tn.x > node_cand.x) tn.x - node_cand.x else node_cand.x - tn.x;
                            const diff_y = if (tn.y > node_cand.y) tn.y - node_cand.y else node_cand.y - tn.y;
                            if ((diff_y <= globals.min_node_dist and diff_x == 0)
                                or (diff_x <= globals.min_node_dist and diff_y == 0)) {
                                //std.debug.print("Too close @ ({}, {})\n", .{node_cand.x, node_cand.y});
                                continue :loop_insert_axi;
                            }
                        }

                        //Connection Check
                        const chk = self.NodeLocateDirUncrossed(i, if (args.horz) .Right else .Down, args.pos);
                        if (chk == null or chk.? != (self.nodes-1)) {
                            //std.debug.print("No connect @ ({}, {})\n", .{node_cand.x, node_cand.y});
                            if (args.pos) break //means we can't continue anymore, for positive case
                            else continue;
                        }

                        //Crossing/Inheritance Check
                        const leftNode = self.NodeLocateDirUncrossed(self.nodes-1, .Right, false);
                        const upNode = self.NodeLocateDirUncrossed(self.nodes-1, .Down, false);
                        if ((leftNode != null and leftNode.? != i and !args.horz and self.grid[leftNode.?].connections.get(.Right) != .None)
                                or (upNode != null and upNode.? != i and args.horz and self.grid[upNode.?].connections.get(.Down) != .None)) {
                            //std.debug.print("Crossing @ ({}, {})\n", .{node_cand.x, node_cand.y});
                            if (args.pos) break // we don't want to cross something
                            else continue;
                        }

                        //Ambiguity Check (would make the graph hard to solve)
                        const unconRight = ucR: {const rightNode = self.NodeLocateDirUncrossed(self.nodes-1, .Right, true); break :ucR (rightNode != null and rightNode != i);};
                        const unconLeft = (leftNode != null and leftNode != i);
                        const unconDown = ucD: {const downNode = self.NodeLocateDirUncrossed(self.nodes-1, .Down, true); break :ucD (downNode != null and downNode != i);};
                        const unconUp = (upNode != null and upNode != i);

                        if (unconRight or unconLeft or unconDown or unconUp) {
                            //std.debug.print("Ambiguous @ ({}, {})\n", .{node_cand.x, node_cand.y});
                            continue;
                        }

                        //Great News we can insert this one
                        //std.debug.print("Based off ({}, {})\n", .{n.x, n.y});
                        //std.debug.print("{s}, {}, {}, {s}, {s}\n", .{
                        //    if (args.valid) "True" else "False",
                        //    args.start,
                        //    args.end,
                        //    if (args.horz) "Horz" else "Vert",
                        //    if (args.pos) "True" else "False",
                        //});
                        //std.debug.print("Inserted at ({}, {})\n\n", .{node_cand.x, node_cand.y});
                        inserted = true;
                        if (args.pos) {
                            n.connections.set(if (args.horz) .Right else .Down, .Single);
                        } else {
                            node_cand.connections.set(if (args.horz) .Right else .Down, .Single);
                        }

                        break :loop_insert_retry;
                    }
                    //std.debug.print("Axi V:{}, P:{} not possible !\n", .{args.horz, args.pos});
                }
                //std.debug.print("({}, {}) failed to locate a valid position on axi R:{}, L:{}, D:{}, U:{}!\n", .{n.x, n.y, !conRight, !conLeft, !conDown, !conUp});
                self.nodes -= 1; //didn't insert, delete it
            }

            if (!inserted) {
                break; //we tried really hard, but oh well
            }
        }
    }

    pub fn DrawGrid(self: *Board) void {
        for (0..self.square) |i| {
            const delta = @as(u32, @truncate(i)) * self.node_space;

            const rg_start: raylib.Vector2 = .{
                .x=@floatFromInt(self.strt_x),
                .y=@floatFromInt(self.strt_y+delta),
            };
            const cg_start: raylib.Vector2 = .{
                .x=@floatFromInt(self.strt_x+delta),
                .y=@floatFromInt(self.strt_y),
            };

            const rg_end: raylib.Vector2 = .{
                .x=@floatFromInt(self.strt_x + board_square - self.node_space),
                .y=rg_start.y,
            };
            const cg_end: raylib.Vector2 = .{
                .x=cg_start.x,
                .y=@floatFromInt(self.strt_y + board_square - self.node_space),
            };
            raylib.drawLineDashed(rg_start, rg_end, 2, 2, raylib.Color.gray);
            raylib.drawLineDashed(cg_start, cg_end, 2, 2, raylib.Color.gray);
        }
    }

    pub fn DrawBridges(self: *Board, user: bool, col: raylib.Color) void {
        for (0..self.nodes) |i| {
            const nd: *Node = &self.grid[i];
            const conArr = if (user) &nd.user_connections else &nd.connections;

            const pix_x: c_int = @intCast(self.strt_x + nd.x * self.node_space - (self.brdg_sz/2));
            const pix_y: c_int = @intCast(self.strt_y + nd.y * self.node_space - (self.brdg_sz/2));

            //Rightwards
            if (conArr.get(.Right) == .Single) {
                const oidx: usize = self.NodeLocateDir(i, .Right, true).?;
                const dist = @abs(self.grid[oidx].x - nd.x);

                raylib.drawRectangle(pix_x, pix_y, @intCast(self.node_space*dist), @intCast(self.brdg_sz), col);
            } else if (conArr.get(.Right) == .Double) {
                const oidx: usize = self.NodeLocateDir(i, .Right, true).?;
                const dist = @abs(self.grid[oidx].x - nd.x);

                raylib.drawRectangle(pix_x, pix_y+@as(c_int, @intCast(self.brdg_sz*1)), @intCast(self.node_space*dist), @intCast(self.brdg_sz), col);
                raylib.drawRectangle(pix_x, pix_y-@as(c_int, @intCast(self.brdg_sz*1)), @intCast(self.node_space*dist), @intCast(self.brdg_sz), col);
            }

            //Downwards
            if (conArr.get(.Down) == .Single) {
                const oidx: usize = self.NodeLocateDir(i, .Down, true).?;
                const dist = @abs(self.grid[oidx].y - nd.y);

                raylib.drawRectangle(pix_x, pix_y, @intCast(self.brdg_sz), @intCast(self.node_space*dist), col);
            } else if (conArr.get(.Down) == .Double) {
                const oidx: usize = self.NodeLocateDir(i, .Down, true).?;
                const dist = @abs(self.grid[oidx].y - nd.y);

                raylib.drawRectangle(pix_x+@as(c_int, @intCast(self.brdg_sz*1)), pix_y, @intCast(self.brdg_sz), @intCast(self.node_space*dist), col);
                raylib.drawRectangle(pix_x-@as(c_int, @intCast(self.brdg_sz*1)), pix_y, @intCast(self.brdg_sz), @intCast(self.node_space*dist), col);
            }

        }
    }

    pub fn DrawNodes(self: *Board) void {
        for (0..self.nodes) |i| {
            const nd: *Node = &self.grid[i];

            const pix_x: c_int = @intCast(self.strt_x + nd.x * self.node_space);
            const pix_y: c_int = @intCast(self.strt_y + nd.y * self.node_space);

            //Draw the Node
            const col = if (nd.user_bridges < nd.bridges) raylib.Color.black else (if (nd.user_bridges == nd.bridges) raylib.Color.dark_green else raylib.Color.red);
            raylib.drawCircle(pix_x, pix_y, @floatFromInt(self.node_rd), col);
            raylib.drawCircle(pix_x, pix_y, @as(f32, @floatFromInt(self.node_rd)) * 0.85, globals.bg_color);

            //Draw the Bridge Count
            const buf = [_:0]u8{'0'+@as(u8, @truncate(nd.bridges))}; //Complaint: I'm not a huge fan of repeatedly stacked @ for casting
            const defFont = raylib.getFontDefault(); //why in the world would this EVER BE AN ERROR?!?!?!
            const txtPixSz = if (defFont) |defaultFont| raylib.measureTextEx(defaultFont, &buf, @as(f32, @floatFromInt(self.text_sz)), 0) else |_| raylib.Vector2{.x=0, .y=0};
            raylib.drawText(&buf, pix_x - @as(u16, @intFromFloat(txtPixSz.x/2)), pix_y - @as(u16, @intFromFloat(txtPixSz.y/2)), @intCast(self.text_sz), globals.tx_color);
        }
    }

    /// Draw the Screen using Raylib
    pub fn Draw(self : *Board, reveal: bool) void {
        self.DrawGrid(); //Draw the Grid first

        if (reveal) self.DrawBridges(false, raylib.Color.green);
        self.DrawBridges(true, if (!reveal) raylib.Color.black else raylib.Color.red);

        self.DrawNodes();
    }

    /// Interact with the board using Raylib
    pub fn Interact(self : *Board) void {
        _ = self;
    }
};
