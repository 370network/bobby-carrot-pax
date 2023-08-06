const std = @import("std");
const jok = @import("jok");
const sdl = jok.sdl;
const j2d = jok.j2d;
const Bobby = @import("Bobby.zig");

const width_points: u32 = 16;
const height_points: u32 = 16;
const view_width_points: u32 = 10;
const view_height_points: u32 = 12;
const width: u32 = 32 * width_points;
const height: u32 = 32 * height_points;
const view_width: u32 = 32 * view_width_points;
const view_height: u32 = 32 * view_height_points;
const scale: f32 = 2.0;

var sheet: *j2d.SpriteSheet = undefined;
var as: *j2d.AnimationSystem = undefined;
var tileset: j2d.Sprite = undefined;

var bobby: Bobby = undefined;
var map_info: ?MapInfo = null;
var currentLevel: usize = 0;

pub const MapInfo = struct {
    data_origin: []const u8,
    start_idx: usize,
    end_idx: usize,
    carrot_total: usize,
    egg_total: usize,

    pub fn data(info: *const MapInfo) []const u8 {
        return info.data_origin[4..];
    }
};

// ==== Game Engine variables and functions
pub const jok_window_title: [:0]const u8 = "Bobby Carrot";
pub const jok_exit_on_recv_esc = false;
pub const jok_window_size = jok.config.WindowSize{
    .custom = .{
        .width = @intFromFloat(@as(f32, width) * scale),
        .height = @intFromFloat(@as(f32, height) * scale),
    },
};

pub fn init(ctx: jok.Context) !void {
    std.log.info("game init", .{});
    try ctx.renderer().setScale(scale, scale);

    // Setup animations
    const size = ctx.getFramebufferSize();
    sheet = try j2d.SpriteSheet.fromPicturesInDir(
        ctx,
        "assets/image",
        @intFromFloat(size.x),
        @intFromFloat(size.y),
        1,
        true,
        .{},
    );
    tileset = sheet.getSpriteByName("tileset").?;
    as = try j2d.AnimationSystem.create(ctx.allocator());
    const bobby_idle = sheet.getSpriteByName("bobby_idle").?;
    const bobby_fade = sheet.getSpriteByName("bobby_fade").?;
    const bobby_death = sheet.getSpriteByName("bobby_death").?;
    try as.add(
        "bobby_idle",
        &[_]j2d.Sprite{
            bobby_idle.getSubSprite(0 * 36, 0, 36, 50),
            bobby_idle.getSubSprite(1 * 36, 0, 36, 50),
            bobby_idle.getSubSprite(2 * 36, 0, 36, 50),
        },
        120.0 / 8,
        true,
    );
    try as.add(
        "fade_in",
        &[_]j2d.Sprite{
            bobby_fade.getSubSprite(8 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(7 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(6 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(5 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(4 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(3 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(2 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(1 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(0 * 36, 0, 36, 50),
        },
        180.0 / 8.0,
        false,
    );
    try as.add(
        "fade_out",
        &[_]j2d.Sprite{
            bobby_fade.getSubSprite(0 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(1 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(2 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(3 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(4 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(5 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(6 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(7 * 36, 0, 36, 50),
            bobby_fade.getSubSprite(8 * 36, 0, 36, 50),
        },
        180.0 / 8.0,
        false,
    );
    try as.add(
        "bobby_death",
        &[_]j2d.Sprite{
            bobby_death.getSubSprite(0 * 44, 0, 44, 54),
            bobby_death.getSubSprite(1 * 44, 0, 44, 54),
            bobby_death.getSubSprite(2 * 44, 0, 44, 54),
            bobby_death.getSubSprite(3 * 44, 0, 44, 54),
            bobby_death.getSubSprite(4 * 44, 0, 44, 54),
            bobby_death.getSubSprite(5 * 44, 0, 44, 54),
            bobby_death.getSubSprite(6 * 44, 0, 44, 54),
            bobby_death.getSubSprite(7 * 44, 0, 44, 54),
        },
        180.0 / 8.0,
        false,
    );
    inline for (.{
        "bobby_left",
        "bobby_right",
        "bobby_up",
        "bobby_down",
    }) |name| {
        const sprite = sheet.getSpriteByName(name).?;
        try as.add(
            name,
            &[_]j2d.Sprite{
                sprite.getSubSprite(0 * 36, 0, 36, 50),
                sprite.getSubSprite(1 * 36, 0, 36, 50),
                sprite.getSubSprite(2 * 36, 0, 36, 50),
                sprite.getSubSprite(3 * 36, 0, 36, 50),
                sprite.getSubSprite(4 * 36, 0, 36, 50),
                sprite.getSubSprite(5 * 36, 0, 36, 50),
                sprite.getSubSprite(6 * 36, 0, 36, 50),
                sprite.getSubSprite(7 * 36, 0, 36, 50),
            },
            30.0,
            true,
        );
    }
    inline for (.{
        "tile_conveyor_left",
        "tile_conveyor_right",
        "tile_conveyor_up",
        "tile_conveyor_down",
    }) |name| {
        const sprite = sheet.getSpriteByName(name).?;
        try as.add(
            name,
            &[_]j2d.Sprite{
                sprite.getSubSprite(0 * 32, 0, 32, 32),
                sprite.getSubSprite(1 * 32, 0, 32, 32),
                sprite.getSubSprite(2 * 32, 0, 32, 32),
                sprite.getSubSprite(3 * 32, 0, 32, 32),
            },
            45.0 / 4.0,
            true,
        );
    }

    try initLevel(ctx);
}

fn initLevel(ctx: jok.Context) !void {
    var buf: [64]u8 = undefined;
    const filename = if (currentLevel < 30) blk: {
        break :blk try std.fmt.bufPrint(&buf, "assets/level/normal{d:0>2}.blm", .{currentLevel + 1});
    } else blk: {
        break :blk try std.fmt.bufPrint(&buf, "assets/level/egg{d:0>2}.blm", .{currentLevel - 30 + 1});
    };
    std.log.info("level file name: {s}", .{filename});

    if (map_info) |info| {
        ctx.allocator().free(info.data_origin);
    }

    // Load level data
    const data = try std.fs.cwd().readFileAlloc(ctx.allocator(), filename, 512);
    var start_idx: usize = 0;
    var end_idx: usize = 0;
    var carrot_total: usize = 0;
    var egg_total: usize = 0;
    for (data[4..], 0..) |byte, idx| {
        switch (byte) {
            19 => carrot_total += 1,
            21 => start_idx = idx,
            44 => end_idx = idx,
            45 => egg_total += 1,
            else => {},
        }
    }
    map_info = MapInfo{
        .data_origin = data,
        .start_idx = start_idx,
        .end_idx = end_idx,
        .carrot_total = carrot_total,
        .egg_total = egg_total,
    };
    std.log.info("map_info: {any}", .{map_info});

    bobby = Bobby.new(ctx.seconds(), map_info.?, as);
}

pub fn event(ctx: jok.Context, e: sdl.Event) !void {
    std.log.debug("[{}] game.event()", .{ctx.seconds()});
    switch (e) {
        .key_up => |key| {
            switch (key.scancode) {
                .q => ctx.kill(),
                .n => {
                    currentLevel = (currentLevel + 1) % 50;
                    try initLevel(ctx);
                },
                .p => {
                    currentLevel = (currentLevel + 49) % 50;
                    try initLevel(ctx);
                },
                .r => try initLevel(ctx),
                else => {},
            }
        },
        else => {},
    }
    try bobby.event(ctx, e);
}

pub fn update(ctx: jok.Context) !void {
    if (bobby.dead) {
        try initLevel(ctx);
    } else if (bobby.faded_out) {
        currentLevel = (currentLevel + 1) % 50;
        try initLevel(ctx);
    }
    try bobby.update(ctx);
}

pub fn draw(ctx: jok.Context) !void {
    // your 2d drawing
    try j2d.begin(.{ .depth_sort = .back_to_forth });

    for (map_info.?.data(), 0..) |byte, idx| {
        var anim_opt = switch (byte) {
            40 => "tile_conveyor_left",
            41 => "tile_conveyor_right",
            42 => "tile_conveyor_up",
            43 => "tile_conveyor_down",
            else => null,
        };
        const pos_x: f32 = @floatFromInt((idx % 16) * 32);
        const pos_y: f32 = @floatFromInt((idx / 16) * 32);
        if (anim_opt) |name| {
            var anim = as.animations.getPtr(name).?;
            if (anim.is_over) anim.reset();
            try j2d.sprite(anim.getCurrentFrame(), .{ .pos = .{ .x = pos_x, .y = pos_y }, .depth = 0.8 });
            anim.update(ctx.deltaSeconds());
        } else {
            const offset_x: f32 = @floatFromInt((byte % 8) * 32);
            const offset_y: f32 = @floatFromInt((byte / 8) * 32);
            try j2d.sprite(
                tileset.getSubSprite(offset_x, offset_y, 32, 32),
                .{ .pos = .{ .x = pos_x, .y = pos_y }, .depth = 1.0 },
            );
        }
    }

    try bobby.draw(ctx);

    try j2d.end();
}

pub fn quit(ctx: jok.Context) void {
    std.log.info("game quit", .{});
    ctx.allocator().free(map_info.?.data_origin);
    as.destroy();
    sheet.destroy();
}
