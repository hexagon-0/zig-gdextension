# A Simple Zig GDExtension

## Introduction

The scope of this tutorial is to recreate the [GDExtension C++ example](https://docs.godotengine.org/en/4.2/tutorials/scripting/gdextension/gdextension_cpp_example.html)
with two main differences:

1. We'll be writing it in [Zig](https://ziglang.org/) instead of C++.
2. No language bindings will be used, only the built-in GDExtension interface.

The goal here is to familiarize ourselves with the GDExtension interface in
order to know what to target when writing code generation for real language
bindings.

## References

A simpler example using C is available [here](https://github.com/gilzoide/hello-gdextension/blob/main/1.hello-c/README.md)
and is the greatest reference for this tutorial.

Reading the inline documentation for [gdextension_interface.h](https://github.com/godotengine/godot/blob/4.2-stable/core/extension/gdextension_interface.h),
as well as the [godot-hpp source code](https://github.com/godotengine/godot-cpp/tree/godot-4.2-stable)
is recommended as a more in-depth reference.

## Getting started

A GDExtension is a dynamic library (.dll on Windows, .so on Linux) loaded by
Godot at runtime (including in the editor). We can use `zig init` to scaffold
a project containing a static library (`src/root.zig`) and an executable
(`src/main.zig`). As we won't be needing the executable, we can remove its file
and associated configuration in `build.zig`. We should also substitute
`addSharedLibrary` for `addStaticLibrary` in order to build a dynamic lib. The
arguments should remain unchanged. After this call, we need to add the `src`
folder to the list of include paths, as we'll be including a C header file
later on. This can be accomplished by calling the `addIncludePath` method on the
`lib` object we just got.

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // Changed from addStaticLibrary
    const lib = b.addSharedLibrary(.{
        .name = "zig-gdextension",
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });
    // Enable Zig to find headers in the src folder
    lib.addIncludePath(.{ .path = "src" });

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
```

Let's now create a Godot project to test our extension. Make a folder alongside
your `build.zig` and `src` folder; I'll call mine `project`, but you can give
it any name, like `demo`.

Create a scene with a single `Node` as root and save it as `main.tscn`.

Lastly before we start writing code, we need a header file containing the type
declarations for the GDExtension interface. The Godot executable can output this
file when run with the `--dump-gdextension-interface` argument. Alternatively,
you can download them [here](https://github.com/godotengine/godot-cpp/tree/godot-4.2-stable/gdextension).

When you've obtained the file, copy it to the `src` folder alongside `root.zig`.

Our folder structure should now look something like this:

```
+-project/
  |
  +-icon.svg
  |
  +-icon.svg.import
  |
  +-main.tscn
  |
  +-project.godot
|
+-src/
  |
  +-gdextension_interface.h
  |
  +-root.zig
|
+-build.zig
|
+-build.zig.zon
```

Let's start writing code for our extension. But where should we begin? Normally,
when writing applications, we would write a `main` function that would serve as
the entry point of our program. However, we're writing a library, so what would
be the entry point of a library? Well, libraries don't actually have an entry
point, since they're meant to be a collection of procedures for other programs
to call. In our case, the other program is Godot, so the more appropriate
question is: what functions does Godot expect us to implement for it to call?

The answer is: a single function with a signature matching
`GDExtensionInitializationFunction` as described in `gdextension_interface.h`:

```
GDExtensionBool my_extension_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization);
```

We don't have to name it `my_extension_init`, we can pick any name and we'll
have to tell this name to Godot later on. Notice that this "single function
library" format dictated by Godot makes our extension function much like a
usual executable program with a `main` entry point.

Now, open `root.zig` in your favorite code editor. You can get rid of all the
pregenerated code. Let's start by including `gdextension_interface.h` at the
top of our file:

```zig
const c = @cImport(
    @cInclude("gdextension_interface.h"),
);
```

Now we can refer to the types declared in the header, neatly contained in the
`c` namespace. Onto our entry point:

```zig
export fn extension_entry(
    p_get_proc_address: c.GDExtensionInterfaceGetProcAddress,
    p_library: c.GDExtensionClassLibraryPtr,
    r_initialization: *c.GDExtensionInitialization,
) callconv(.C) c.GDExtensionBool {
    _ = p_get_proc_address;
    _ = p_library;
    _ = r_initialization;

    return @intFromBool(true);
}
```

That would be the Zig-ified version of `my_extension_init`. Two important
things to notice:

- The `export` keyword at the beginning makes our function visible in the DLL
  so Godot can find it.

- Any function we pass to Godot needs to be in the C language's calling
  convention (if you don't know what that is, look it up later). That can be
  accomplished in Zig by adding `callconv(.C)` between the parameter list and
  the return type.

Also, we're returning `@intFromBool(true)` instead of just `true` because our
`GDExtensionBool` return type is an 8-bit integer (`uint8_t` in C), and I
couldn't find information on whether it's OK to implicitly cast from `bool`, so
we'll try to play it safe here.

One last thing before we set this up in Godot: we are expected to fill the
`initialize` and `deinitialize` members of `r_initialization` with our own
functions, so let's do that.

First, let's write the functions. Don't forget `callconv(.C)` as I often do:

```zig
fn initialize(userdata: ?*anyopaque, level: c.GDExtensionInitializationLevel) callconv(.C) void {
    _ = userdata;
    _ = level;
}

fn deinitialize(userdata: ?*anyopaque, level: c.GDExtensionInitializationLevel) callconv(.C) void {
    _ = userdata;
    _ = level;
}
```

Then, assign them inside `extension_entry`:

```zig
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
```

Let's build it so we can use it in our project. We'll specify an installation
prefix inside our `project` folder so we don't have to move it manually later:

```sh
zig build install -p project/my-extension
```

If all works well, that will create a folder named `my-extension`, containing
another folder called `lib` (blame Zig for that) where our `zig-gdextension.dll`
(or `libzig-gdextension.so`, if you're on linux) will reside.

Now let's tell Godot about our extension. Inside `my-extension`, create a file
with a name ending in `.gdextension`. I've named mine
`my-extension.gdextension`. Write the following contents:

```
[configuration]
entry_symbol = "extension_entry"
compatibility_minimum = 4.2

[libraries]
windows.x86_64 = "lib/zig-gdextension.dll"
linux.x86_64 = "lib/libzig-gdextension.so"
macos = "lib/libzig-gdextension.dylib"
```

Under `[configuration]`, we tell it the name of our `entry_symbol` and the
minimum engine version our extension requires. In the `[libraries]` section,
we point to the compiled libraries for each system and architecture (in our
case, only 64-bit). We don't need to have all of these files present, only the
one corresponding to the system  we're running the project (and editor) in.

If we open Godot now, nothing different will happen. Does that mean it worked?
Does it mean it didn't work? We can't tell since our extension does absolutely
nothing right now. Since it'll be a little while until it does something we can
see in the editor, let's use `std.debug.print` to check on the initialization:

```zig
const std = @import("std");

fn initialize(userdata: ?*anyopaque, level: c.GDExtensionInitializationLevel) callconv(.C) void {
    _ = userdata;

    std.debug.print("initialization at level {}\n", .{level});
}

fn deinitialize(userdata: ?*anyopaque, level: c.GDExtensionInitializationLevel) callconv(.C) void {
    _ = userdata;

    std.debug.print("deinitialization at level {}\n", .{level});
}
```

The `userdata` parameter is a pointer-to-anything that we can use to store any
data we might need. For example: we could allocate a struct in our entry point
and assign its address to the `userdata` field in `r_initialization`. Godot does
not care what this data is, it simply passes the pointer along to our functions.

Godot's (de)initialization is comprised of several levels. You can find them in
the `GDExtensionInitializationLevel`. [gilzoide's article](https://github.com/gilzoide/hello-gdextension/blob/main/1.hello-c/README.md)
briefly describes them:

> - `GDEXTENSION_INITIALIZATION_CORE`: happens right after the engine's core modules are initialized.
> - `GDEXTENSION_INITIALIZATION_SERVERS`: happens right after the engine's servers are initialized.
> - `GDEXTENSION_INITIALIZATION_SCENE`: happens right after the engine's runtime classes are registered.
>     Only then classes, including core ones like `Object`, `Reference` and `Node`, are in the ClassDB and may be extended.
> - `GDEXTENSION_INITIALIZATION_EDITOR`: happens only in the editor, right after editor classes are registered, like `EditorPlugin`.
>   Use this for editor-only code in extensions.

Or (de)initialize function will be called once in each level, and we can use the
`level` parameter to tell which. Later in this tutorial, we'll be registering a
class, so we must wait for `GDEXTENSION_INITIALIZATION_SCENE`. Right now, we'll
just print the current level.

After rebuilding the library (don't forget to specify the installation prefix),
we can run Godot to give it a go. However, since we're calling an OS `print` and
not a Godot `print`, we'll need to launch Godot from a terminal/command prompt
to see the output. If you've downloaded the engine from the official website,
there should be a Godot executable ending in `_console` inside the package. It
will launch Godot normally but with a console attached, so you can open your
project from there to see the result.

Alternatively, you can use your terminal to navigate to the `project` folder and
launch Godot from there. The following command arguments can be useful to
quickly test initialization, as they will instruct the engine to run the project
without video or audio and quit after a single frame:

```sh
godot --headless --quit
```

Launching Godot either way should print, among other things, the following
lines:

```
initialization at level 0
initialization at level 1
initialization at level 2
initialization at level 3
deinitialization at level 3
deinitialization at level 2
deinitialization at level 1
deinitialization at level 0
```

If you see that, it means our extension is initializing just fine!

