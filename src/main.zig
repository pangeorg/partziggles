const rl = @import("raylib");
const std = @import("std");
const rand = std.crypto.random;
const math = std.math;

const N_MASSES = 125;

const Mass = struct {
    r: @Vector(2, f32),
    mass: f32,
    velocity: @Vector(2, f32),
    const Self = @This();

    const default: Mass = .{
        .r = @Vector(2, f32){ 0, 0 },
        .mass = 0,
        .velocity = @Vector(2, f32){ 0, 0 },
    };

    pub fn render(self: Mass) void {
        const x: i32 = saveCast(self.r[0]);
        const y: i32 = saveCast(self.r[1]);
        rl.drawCircle(x, y, self.mass * 3, rl.Color.white);
    }

    pub fn apply_force(self: *Self, f: @Vector(2, f32), dt: f32) void {
        self.velocity += (f * as2dvec(dt / self.mass));
        self.r += self.velocity * as2dvec(dt);
    }
};

fn saveCast(val: f32) i32 {
    if ((val < 0.5) and (val > -0.5)) {
        return 0;
    }
    return @as(i32, @intFromFloat(val));
}

fn as2dvec(value: f32) @Vector(2, f32) {
    return @as(@Vector(2, f32), @splat(value));
}

fn random_sign() f32 {
    if (rand.boolean()) return 1;
    return -1;
}

fn random_mass(center: f32) Mass {
    const x: f32 = center + rand.float(f32) * 300 * random_sign();
    const y: f32 = center + rand.float(f32) * 300 * random_sign();
    return Mass{
        .r = @Vector(2, f32){ x, y },
        .mass = 3 + rand.float(f32) * random_sign(), // rand.float(f32) * 9.9 + 0.1,
        .velocity = @Vector(2, f32){ 0, 0 },
    };
}

fn distance(comptime T: type, a: @Vector(2, T), b: @Vector(2, T)) @Vector(2, T) {
    return length(f32, b - a);
}

fn length(comptime T: type, a: @Vector(2, T)) T {
    return math.sqrt(dot(f32, a, a));
}

fn norm(comptime T: type, a: @Vector(2, T)) @Vector(2, T) {
    return a / as2dvec(length(f32, a));
}

fn dot(comptime T: type, a: @Vector(2, T), b: @Vector(2, T)) T {
    return @reduce(.Add, a * b);
}

fn force(m1: *Mass, m2: *Mass) @Vector(2, f32) {
    // calculates the force applied on body 2 exerted by body 1
    const d = m2.r - m1.r;
    const l = math.pow(f32, length(f32, d), 2);

    if (l == 0) {
        return @Vector(2, f32){ 0, 0 };
    }

    const n = norm(f32, d);
    const c = m1.mass * m2.mass / l * 1e5;
    return -as2dvec(c) * n;
}

fn total_force(masses: *std.ArrayList(Mass), m: *Mass) @Vector(2, f32) {
    var f = @Vector(2, f32){ 0, 0 };
    for (masses.items) |*mass| {
        f = f + force(mass, m);
    }
    return f;
}

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;
    const FPS = 60;
    const DT: f32 = 1.0 / 10.0 / 60.0;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var masses = std.ArrayList(Mass).init(allocator);
    defer masses.deinit();
    for (0..N_MASSES) |_| {
        try masses.append(random_mass(400));
    }

    var forces = std.ArrayList(@Vector(2, f32)).init(allocator);
    for (0..N_MASSES) |_| {
        try forces.append(@Vector(2, f32){ 0, 0 });
    }

    var mark_deletion = std.ArrayList(usize).init(allocator);
    defer mark_deletion.deinit();

    rl.initWindow(screenWidth, screenHeight, "Partziggles");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(FPS);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        if (rl.isMouseButtonReleased(rl.MouseButton.mouse_button_left)) {
            const m: Mass = .{
                .r = @Vector(2, f32){ @floatFromInt(rl.getMouseX()), @floatFromInt(rl.getMouseY()) },
                .mass = 3,
                .velocity = @Vector(2, f32){ 0, 0 },
            };
            try masses.append(m);
            try forces.append(@Vector(2, f32){ 0, 0 });
        }

        for (0..mark_deletion.items.len) |i| {
            _ = masses.swapRemove(i);
            _ = forces.pop();
        }
        mark_deletion.clearRetainingCapacity();

        for (masses.items, 0..) |*mass, i| {
            forces.items[i] = total_force(&masses, mass);
        }

        for (masses.items, 0..) |*mass, i| {
            mass.apply_force(forces.items[i], DT);
            if (mass.r[0] < 0 or
                mass.r[0] > screenWidth or
                mass.r[1] < 0 or
                mass.r[1] > screenHeight)
            {
                try mark_deletion.append(i);
            }
            mass.render();
        }
    }
}
