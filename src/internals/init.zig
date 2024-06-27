const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const Allocator = std.mem.Allocator;
const fs_helpers = @import("fs_helpers.zig");
const containsSubstring = @import("str_helpers.zig").containsSubstring;
const parseConfig = @import("userPrefs.zig").parseConfig;
const types = @import("types.zig");
const UserSettings = types.UserSettings;
const Controller = @import("controller.zig");
const btnActions = @import("btnActions.zig");
const c1 = @import("c1.zig");

/// check that realearn can be found in `fxtags.ini`
fn isRealearnInstalled() !bool {
    const resourcePath = reaper.GetResourcePath();
    const mem_rpath = std.mem.sliceTo(resourcePath, 0);
    var file_path: [std.fs.max_path_bytes]u8 = undefined;
    @memcpy(&file_path, mem_rpath);
    @memcpy(file_path[mem_rpath.len..], [1]u8{std.fs.path.sep} ++ "reaper-fxtags.ini");

    //Open the file
    const file = try std.fs.openFileAbsolute(&file_path, .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const r = br.reader();

    var buf: [1024]u8 = undefined;

    const ref: []const u8 = "realearn";
    // const searchString = std.mem.span(ref, 0);
    while (try r.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (containsSubstring(ref, line)) {
            return true;
        }
    }

    return false;
}

// C: MediaTrack* GetMasterTrack(ReaProject* proj)
// -- get a track from a project by track count (zero-based) (proj=0 for active project)
// C: int TrackFX_GetRecCount(MediaTrack* track)
// -- On the master track, this accesses monitoring FX rather than record input FX.
// reaper.TrackFX_GetRecCount(reaper.GetMasterTrack(0))
// -- iterate
// C: bool TrackFX_GetFXName(MediaTrack* track, int fx, char* bufOut, int bufOut_sz)
// -- FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track)
fn isRealearnOnMonitoring() !bool {
    const cur_proj = reaper.EnumProjects(-1, null);
    const masterTrack = reaper.GetMasterTrack(cur_proj);
    const fxCount = reaper.TrackFX_GetRecCount(masterTrack);
    for (0..@intCast(fxCount)) |fxIndex| {
        const search_str = "realearn";
        const t = 0x1000000;
        const x: u32 = @intCast(fxIndex);
        const z: c_int = @intCast(t + x);

        var buf: [128]u8 = undefined;
        const buffer: []u8 = &buf;
        const has_fx_name = reaper.TrackFX_GetFXName(masterTrack, z, @ptrCast(&buf[0]), buf.len);
        if (has_fx_name) {
            if (containsSubstring(search_str, buffer)) {
                return true;
            }
        }
    }
    return false;
}

pub const InitError = error{
    RealearnNotInstalled,
};

var controller = Controller.c1;

/// retrieve user settings
/// check tha realearn’s installed,
/// check whether realearn instances are present on fx monitoring
/// (load them if not)
/// retrieve the controller config
/// register the actions for each of the buttons
/// return the hook command function that
pub fn init(allocator: Allocator) !void {
    const userSettings = try parseConfig(allocator, "c1");
    _ = userSettings;
    const isInstalled = try isRealearnInstalled();
    if (!isInstalled) {
        return InitError.RealearnNotInstalled;
    }
    const isOnMonitoring = try isRealearnOnMonitoring();
    if (!isOnMonitoring) {
        reaper.ShowConsoleMsg("Realearn is not on monitoring FX chain\n");
    } else {
        reaper.ShowConsoleMsg("Realearn found\n");
    }
    // const config_paths = try controllerConfigLoader.getControllerPath(allocator, controller.name);
    // _ = config_paths;
    _ = try btnActions.registerButtonActions(allocator, &controller);
}
