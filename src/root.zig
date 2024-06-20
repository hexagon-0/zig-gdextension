const std = @import("std");
const c = @cImport(
    @cInclude("gdextension_interface.h"),
);

fn initialize(userdata: ?*anyopaque, level: c.GDExtensionInitializationLevel) callconv(.C) void {
    _ = userdata;

    std.debug.print("initialization at level {}\n", .{level});
}

fn deinitialize(userdata: ?*anyopaque, level: c.GDExtensionInitializationLevel) callconv(.C) void {
    _ = userdata;

    std.debug.print("deinitialization at level {}\n", .{level});
}

export fn extension_entry(
    p_get_proc_address: c.GDExtensionInterfaceGetProcAddress,
    p_library: c.GDExtensionClassLibraryPtr,
    r_initialization: *c.GDExtensionInitialization,
) callconv(.C) c.GDExtensionBool {
    _ = p_get_proc_address;
    _ = p_library;

    r_initialization.initialize = initialize;
    r_initialization.deinitialize = deinitialize;

    return @intFromBool(true);
}
