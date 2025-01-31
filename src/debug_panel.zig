const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const State = @import("statemachine.zig").State;
const logger = @import("logger.zig");

const DEBUG_BUF_SIZE = 512;

pub fn safePrint(buf: [:0]u8, comptime fmt: []const u8, args: anytype) ![:0]const u8 {
    return std.fmt.bufPrintZ(buf, fmt, args) catch |err| switch (err) {
        error.NoSpaceLeft => blk: {
            const ellipsis = "…";
            const end = buf.len - ellipsis.len - 1;
            @memcpy(buf[end .. end + ellipsis.len], ellipsis);
            buf[end + ellipsis.len] = '\x00';
            break :blk @as([:0]const u8, buf[0 .. end + ellipsis.len :0]);
        },
        else => return err,
    };
}

pub fn drawDebugPanel(ctx: imgui.ContextPtr, state: *State, event_log: *logger.EventLog) !void {
    if (try imgui.Begin(.{ ctx, "Debug Panel" })) {
        defer imgui.End(.{ctx}) catch {};

        var buf: [DEBUG_BUF_SIZE:0]u8 = undefined;

        // Current State Section
        const mode_text = try safePrint(&buf, "Current Mode: {s}", .{@tagName(state.current_mode)});
        try imgui.TextWrapped(.{ ctx, mode_text });

        if (try imgui.CollapsingHeader(.{ ctx, "Recent Events" })) {
            if (try imgui.BeginTable(.{ ctx, "Events", 3 })) {
                defer imgui.EndTable(.{ctx}) catch {};
                // defer imgui.EndTable(.{ctx}) catch {};

                try imgui.TableSetupColumn(.{ ctx, "Type" });
                try imgui.TableSetupColumn(.{ ctx, "Details" });
                try imgui.TableHeadersRow(.{ctx});

                // Get recent events (last 10 for example)
                for (event_log.getEventsByType(.state_change, 10)) |event| {
                    try imgui.TableNextRow(.{ctx});

                    if (try imgui.TableNextColumn(.{ctx})) {
                        const event_type = try safePrint(&buf, "{s}", .{@tagName(event)});
                        try imgui.Text(.{ ctx, event_type });
                    }

                    if (try imgui.TableNextColumn(.{ctx})) {
                        switch (event) {
                            .state_change => |change| {
                                const state_text = try safePrint(&buf, "{s} -> {s}", .{ @tagName(change.old_mode), @tagName(change.new_mode) });
                                try imgui.Text(.{ ctx, state_text });
                            },
                            else => {},
                        }
                    }
                }
            }
        }

        if (try imgui.CollapsingHeader(.{ ctx, "Track State" })) {
            const track_text = try safePrint(&buf, "Last Touched Track: {d}", .{state.last_touched_tr_id});
            try imgui.Text(.{ ctx, track_text });

            if (state.fx_ctrl.fxMap.COMP) |comp| {
                const comp_text = try safePrint(&buf, "Comp FX: {d}", .{comp[0]});
                try imgui.Text(.{ ctx, comp_text });
            }
        }

        if (try imgui.CollapsingHeader(.{ ctx, "MIDI Monitor" })) {
            // Show recent MIDI activity
            // Could add meters visualization here

            var it = event_log.ring_buffer.reverse_iterator();
            while (it.next()) |event| {
                if (@as(logger.EventType, event) == .midi_input) {
                    const midi_text = try safePrint(&buf, "CC: {s} Val: {d}", .{ @tagName(event.midi_input.cc), event.midi_input.value });
                    try imgui.Text(.{ ctx, midi_text });
                }
            }
        }
    }
}

test "safePrint" {
    const testing = std.testing;
    const expect = testing.expect;
    const expectEqualStrings = testing.expectEqualStrings;

    // Test buffer that's large enough
    {
        var buf: [32:0]u8 = undefined;
        const result = try safePrint(&buf, "test {d}", .{42});
        try expectEqualStrings("test 42", result);
    }

    // Test buffer that's exactly the right size (including null terminator)
    {
        var buf: [8:0]u8 = undefined;
        const result = try safePrint(&buf, "test {d}", .{42});
        try expectEqualStrings("test 42", result);
    }

    // Test truncation
    {
        var buf: [7:0]u8 = undefined;
        const result = try safePrint(&buf, "test {d}", .{42});
        try expectEqualStrings("tes…", result);
    }

    // Test very small buffer
    {
        var buf: [4:0]u8 = undefined;
        const result = try safePrint(&buf, "test this", .{});
        try expectEqualStrings("…", result);
    }

    // Test empty format string
    {
        var buf: [8:0]u8 = undefined;
        const result = try safePrint(&buf, "", .{});
        try expectEqualStrings("", result);
    }

    // Verify null termination
    {
        var buf: [8:0]u8 = undefined;
        _ = try safePrint(&buf, "test", .{});
        try expect(buf[4] == 0);
    }
}
