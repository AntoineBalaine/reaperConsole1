const std = @import("std");
const c1 = @import("c1.zig");
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const State = statemachine.State;
const globals = @import("globals.zig");
const mappings = @import("mappings.zig");
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.mapping_actions);

pub const MappingAction = union(enum) {
    // Parameter selection
    select_parameter: ?u32, // null to deselect

    // Control selection
    select_control: ?c1.CCs, // null to deselect

    // MIDI learn
    toggle_midi_learn: void,

    // Mapping operations
    add_mapping: struct {
        param: u8,
        control: c1.CCs,
    },
    remove_mapping: c1.CCs, // Remove mapping for this control

    // Panel operations
    save_mapping: void, // Save current mappings to MapStore
    cancel_mapping: void, // Discard changes and exit mapping mode
};

pub fn mappingActions(state: *State, map_action: MappingAction) void {
    switch (map_action) {
        .select_parameter => |maybe_param| {
            log.debug("Selected parameter: {?}", .{maybe_param});
            state.mapping.selected_parameter = maybe_param;
            // If we're in MIDI learn mode and a parameter is selected,
            // we're ready to receive MIDI input
        },
        .select_control => |maybe_control| {
            log.debug("Selected control: {s}", .{if (maybe_control) |cc| @tagName(cc) else "none"});
            state.mapping.selected_control = maybe_control;
            // If both parameter and control are selected, could auto-add mapping
        },
        .toggle_midi_learn => {
            log.debug("MIDI learn {s}", .{if (state.mapping.midi_learn_active) "disabled" else "enabled"});
            state.mapping.midi_learn_active = !state.mapping.midi_learn_active;
            if (!state.mapping.midi_learn_active) {
                // Clear selection when exiting MIDI learn mode?
                state.mapping.selected_control = null;
            }
        },
        .add_mapping => |mapping| {
            log.info("Added mapping: {s} -> param {d}", .{ @tagName(mapping.control), mapping.param });
            // Add to current_mappings based on module type
            switch (state.mapping.current_mappings) {
                .COMP => |*comp| switch (mapping.control) {
                    .Comp_Attack => comp.Comp_Attack = mapping.param,
                    .Comp_DryWet => comp.Comp_DryWet = mapping.param,
                    .Comp_Ratio => comp.Comp_Ratio = mapping.param,
                    .Comp_Release => comp.Comp_Release = mapping.param,
                    .Comp_Thresh => comp.Comp_Thresh = mapping.param,
                    .Comp_comp => comp.Comp_comp = mapping.param,
                    else => {},
                },
                .EQ => |*eq| switch (mapping.control) {
                    .Eq_HiFrq => eq.Eq_HiFrq = mapping.param,
                    .Eq_HiGain => eq.Eq_HiGain = mapping.param,
                    .Eq_HiMidFrq => eq.Eq_HiMidFrq = mapping.param,
                    .Eq_HiMidGain => eq.Eq_HiMidGain = mapping.param,
                    .Eq_HiMidQ => eq.Eq_HiMidQ = mapping.param,
                    .Eq_LoFrq => eq.Eq_LoFrq = mapping.param,
                    .Eq_LoGain => eq.Eq_LoGain = mapping.param,
                    .Eq_LoMidFrq => eq.Eq_LoMidFrq = mapping.param,
                    .Eq_LoMidGain => eq.Eq_LoMidGain = mapping.param,
                    .Eq_LoMidQ => eq.Eq_LoMidQ = mapping.param,
                    .Eq_eq => eq.Eq_eq = mapping.param,
                    .Eq_hp_shape => eq.Eq_hp_shape = mapping.param,
                    .Eq_lp_shape => eq.Eq_lp_shape = mapping.param,
                    else => {},
                },
                .INPUT => |*input| switch (mapping.control) {
                    .Inpt_Gain => input.Inpt_Gain = mapping.param,
                    .Inpt_HiCut => input.Inpt_HiCut = mapping.param,
                    .Inpt_LoCut => input.Inpt_LoCut = mapping.param,
                    .Inpt_disp_mode => input.Inpt_disp_mode = mapping.param,
                    .Inpt_disp_on => input.Inpt_disp_on = mapping.param,
                    .Inpt_filt_to_comp => input.Inpt_filt_to_comp = mapping.param,
                    .Inpt_phase_inv => input.Inpt_phase_inv = mapping.param,
                    .Inpt_preset => input.Inpt_preset = mapping.param,
                    else => {},
                },
                .OUTPT => |*output| switch (mapping.control) {
                    .Out_Drive => output.Out_Drive = mapping.param,
                    .Out_DriveChar => output.Out_DriveChar = mapping.param,
                    .Out_Pan => output.Out_Pan = mapping.param,
                    .Out_Vol => output.Out_Vol = mapping.param,
                    else => {},
                },
                .GATE => |*gate| switch (mapping.control) {
                    .Shp_Gate => gate.Shp_Gate = mapping.param,
                    .Shp_GateRelease => gate.Shp_GateRelease = mapping.param,
                    .Shp_Punch => gate.Shp_Punch = mapping.param,
                    .Shp_hard_gate => gate.Shp_hard_gate = mapping.param,
                    .Shp_shape => gate.Shp_shape = mapping.param,
                    .Shp_sustain => gate.Shp_sustain = mapping.param,
                    else => {},
                },
            }
            // Clear selections after mapping
            state.mapping.selected_parameter = null;
            state.mapping.selected_control = null;
        },
        .remove_mapping => |control| {
            log.info("Removed mapping for control: {s}", .{@tagName(control)});
            // Remove from current_mappings based on module type
            switch (state.mapping.current_mappings) {
                .COMP => |*comp| switch (control) {
                    .Comp_Attack => comp.Comp_Attack = mappings.UNMAPPED_PARAM,
                    .Comp_DryWet => comp.Comp_DryWet = mappings.UNMAPPED_PARAM,
                    .Comp_Ratio => comp.Comp_Ratio = mappings.UNMAPPED_PARAM,
                    .Comp_Release => comp.Comp_Release = mappings.UNMAPPED_PARAM,
                    .Comp_Thresh => comp.Comp_Thresh = mappings.UNMAPPED_PARAM,
                    .Comp_comp => comp.Comp_comp = mappings.UNMAPPED_PARAM,
                    else => {},
                },
                .EQ => |*eq| switch (control) {
                    .Eq_HiFrq => eq.Eq_HiFrq = mappings.UNMAPPED_PARAM,
                    .Eq_HiGain => eq.Eq_HiGain = mappings.UNMAPPED_PARAM,
                    .Eq_HiMidFrq => eq.Eq_HiMidFrq = mappings.UNMAPPED_PARAM,
                    .Eq_HiMidGain => eq.Eq_HiMidGain = mappings.UNMAPPED_PARAM,
                    .Eq_HiMidQ => eq.Eq_HiMidQ = mappings.UNMAPPED_PARAM,
                    .Eq_LoFrq => eq.Eq_LoFrq = mappings.UNMAPPED_PARAM,
                    .Eq_LoGain => eq.Eq_LoGain = mappings.UNMAPPED_PARAM,
                    .Eq_LoMidFrq => eq.Eq_LoMidFrq = mappings.UNMAPPED_PARAM,
                    .Eq_LoMidGain => eq.Eq_LoMidGain = mappings.UNMAPPED_PARAM,
                    .Eq_LoMidQ => eq.Eq_LoMidQ = mappings.UNMAPPED_PARAM,
                    .Eq_eq => eq.Eq_eq = mappings.UNMAPPED_PARAM,
                    .Eq_hp_shape => eq.Eq_hp_shape = mappings.UNMAPPED_PARAM,
                    .Eq_lp_shape => eq.Eq_lp_shape = mappings.UNMAPPED_PARAM,
                    else => {},
                },
                .INPUT => |*input| switch (control) {
                    .Inpt_Gain => input.Inpt_Gain = mappings.UNMAPPED_PARAM,
                    .Inpt_HiCut => input.Inpt_HiCut = mappings.UNMAPPED_PARAM,
                    .Inpt_LoCut => input.Inpt_LoCut = mappings.UNMAPPED_PARAM,
                    .Inpt_disp_mode => input.Inpt_disp_mode = mappings.UNMAPPED_PARAM,
                    .Inpt_disp_on => input.Inpt_disp_on = mappings.UNMAPPED_PARAM,
                    .Inpt_filt_to_comp => input.Inpt_filt_to_comp = mappings.UNMAPPED_PARAM,
                    .Inpt_phase_inv => input.Inpt_phase_inv = mappings.UNMAPPED_PARAM,
                    .Inpt_preset => input.Inpt_preset = mappings.UNMAPPED_PARAM,
                    else => {},
                },
                .OUTPT => |*output| switch (control) {
                    .Out_Drive => output.Out_Drive = mappings.UNMAPPED_PARAM,
                    .Out_DriveChar => output.Out_DriveChar = mappings.UNMAPPED_PARAM,
                    .Out_Pan => output.Out_Pan = mappings.UNMAPPED_PARAM,
                    .Out_Vol => output.Out_Vol = mappings.UNMAPPED_PARAM,
                    else => {},
                },
                .GATE => |*gate| switch (control) {
                    .Shp_Gate => gate.Shp_Gate = mappings.UNMAPPED_PARAM,
                    .Shp_GateRelease => gate.Shp_GateRelease = mappings.UNMAPPED_PARAM,
                    .Shp_Punch => gate.Shp_Punch = mappings.UNMAPPED_PARAM,
                    .Shp_hard_gate => gate.Shp_hard_gate = mappings.UNMAPPED_PARAM,
                    .Shp_shape => gate.Shp_shape = mappings.UNMAPPED_PARAM,
                    .Shp_sustain => gate.Shp_sustain = mappings.UNMAPPED_PARAM,
                    else => {},
                },
            }
        },
        .save_mapping => {
            log.info("Saved mappings for FX: {s}", .{state.mapping.target_fx});
            // Save to MapStore
            switch (state.mapping.current_mappings) {
                .INPUT => |input| globals.map_store.INPUT.put(globals.allocator, state.mapping.target_fx, input) catch {},
                .GATE => |gate| globals.map_store.GATE.put(globals.allocator, state.mapping.target_fx, gate) catch {},
                .EQ => |eq| globals.map_store.EQ.put(globals.allocator, state.mapping.target_fx, eq) catch {},
                .COMP => |comp| globals.map_store.COMP.put(globals.allocator, state.mapping.target_fx, comp) catch {},
                .OUTPT => |outpt| globals.map_store.OUTPT.put(globals.allocator, state.mapping.target_fx, outpt) catch {},
            }

            globals.map_store.saveToFile(state.mapping) catch {
                log.warn("Failed to save mapping {s} to file", .{state.mapping.target_fx});
            };

            // Clean up mapping panel
            if (globals.mapping_panel) |*panel| {
                panel.deinit();
                globals.mapping_panel = null;
            }
            dispatch(state, .{ .change_mode = .fx_ctrl });
        },
        .cancel_mapping => {
            log.info("Cancelled mapping for FX: {s}", .{state.mapping.target_fx});
            // Clean up mapping state
            state.mapping.selected_parameter = null;
            state.mapping.selected_control = null;
            state.mapping.midi_learn_active = false;

            // Free allocated memory
            state.mapping.deinit(globals.allocator);

            // Clean up mapping panel
            if (globals.mapping_panel) |*panel| {
                panel.deinit();
                globals.mapping_panel = null;
            }

            // Switch back to previous mode
            dispatch(state, .{ .change_mode = .fx_ctrl });
        },
    }
}

// test "MappingState - initialization and basic operations" {
//     const testing = std.testing;
//     const gpa = testing.allocator;
//
//     // Test init
//     const fx_name = "Test FX";
//     var mapping_state = try statemachine.MappingState.init(gpa, fx_name, .COMP);
//     defer mapping_state.deinit(gpa);
//
//     try testing.expectEqualStrings(fx_name, mapping_state.target_fx);
//     try testing.expect(mapping_state.current_mappings == .COMP);
//     try testing.expect(mapping_state.selected_parameter == null);
//     try testing.expect(mapping_state.selected_control == null);
//     try testing.expect(mapping_state.midi_learn_active == false);
// }
//
// test "MappingActions - parameter and control selection" {
//     const testing = std.testing;
//     const gpa = testing.allocator;
//
//     var state = State.init(gpa);
//     defer state.deinit(gpa);
//
//     // Initialize mapping state
//     state.mapping = try statemachine.MappingState.init(gpa, "Test FX", .COMP);
//     state.current_mode = .mapping_panel;
//
//     // Test parameter selection
//     dispatch(&state, .{ .mapping = .{ .select_parameter = 1 } });
//     try testing.expect(state.mapping.selected_parameter.? == 1);
//
//     // Test parameter deselection
//     dispatch(&state, .{ .mapping = .{ .select_parameter = null } });
//     try testing.expect(state.mapping.selected_parameter == null);
//
//     // Test control selection
//     dispatch(&state, .{ .mapping = .{ .select_control = .Comp_Attack } });
//     try testing.expect(state.mapping.selected_control.? == .Comp_Attack);
//
//     // Test control deselection
//     dispatch(&state, .{ .mapping = .{ .select_control = null } });
//     try testing.expect(state.mapping.selected_control == null);
// }
//
// test "MappingActions - MIDI learn toggle" {
//     const testing = std.testing;
//     const gpa = testing.allocator;
//
//     var state = State.init(gpa);
//     defer state.deinit(gpa);
//
//     state.mapping = try statemachine.MappingState.init(gpa, "Test FX", .COMP);
//     state.current_mode = .mapping_panel;
//
//     // Test MIDI learn activation
//     dispatch(&state, .{ .mapping = .toggle_midi_learn });
//     try testing.expect(state.mapping.midi_learn_active == true);
//
//     // Test MIDI learn deactivation
//     dispatch(&state, .{ .mapping = .toggle_midi_learn });
//     try testing.expect(state.mapping.midi_learn_active == false);
//     try testing.expect(state.mapping.selected_control == null);
// }
//
// test "MappingActions - add and remove mappings" {
//     const testing = std.testing;
//     const gpa = testing.allocator;
//
//     var state = State.init(gpa);
//     defer state.deinit(gpa);
//
//     state.mapping = try statemachine.MappingState.init(gpa, "Test FX", .COMP);
//     state.current_mode = .mapping_panel;
//
//     // Test adding mapping
//     dispatch(&state, .{
//         .mapping = .{
//             .add_mapping = .{
//                 .param = 1,
//                 .control = .Comp_Attack,
//             },
//         },
//     });
//
//     // Verify mapping was added
//     switch (state.mapping.current_mappings) {
//         .COMP => |comp| try testing.expect(comp.Comp_Attack == 1),
//         else => try testing.expect(false),
//     }
//
//     // Test removing mapping
//     dispatch(&state, .{
//         .mapping = .{
//             .remove_mapping = .Comp_Attack,
//         },
//     });
//
//     // Verify mapping was removed
//     switch (state.mapping.current_mappings) {
//         .COMP => |comp| try testing.expect(comp.Comp_Attack == mappings.UNMAPPED_PARAM),
//         else => try testing.expect(false),
//     }
// }
//
// test "MappingActions - save and cancel" {
//     const testing = std.testing;
//     const gpa = testing.allocator;
//
//     // Initialize global state (required for save operation)
//     globals.allocator = gpa;
//     globals.map_store = mappings.init(gpa);
//     defer globals.map_store.deinit();
//
//     var state = State.init(gpa);
//     defer state.deinit(gpa);
//
//     state.mapping = try statemachine.MappingState.init(gpa, "Test FX", .COMP);
//     state.current_mode = .mapping_panel;
//
//     // Add a mapping
//     dispatch(&state, .{
//         .mapping = .{
//             .add_mapping = .{
//                 .param = 1,
//                 .control = .Comp_Attack,
//             },
//         },
//     });
//
//     // Test save mapping
//     dispatch(&state, .{
//         .mapping = .save_mapping,
//     });
//
//     // Verify mode changed and mapping was saved
//     try testing.expect(state.current_mode == .fx_ctrl);
//     if (globals.map_store.COMP.get("Test FX")) |saved_mapping| {
//         try testing.expect(saved_mapping.Comp_Attack == 1);
//     } else {
//         try testing.expect(false);
//     }
//
//     // Test cancel mapping
//     state.mapping = try statemachine.MappingState.init(gpa, "Test FX 2", .COMP);
//     state.current_mode = .mapping_panel;
//     dispatch(&state, .{
//         .mapping = .cancel_mapping,
//     });
//
//     try testing.expect(state.current_mode == .fx_ctrl);
//     try testing.expect(globals.map_store.COMP.get("Test FX 2") == null);
// }
