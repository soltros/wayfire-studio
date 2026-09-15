# Soltros Shell

A personal Wayland desktop shell built around Wayfire and designed as Soltros Shell:
a transformable workspace with dark navy glass surfaces, cyan accents, adaptive
sidebars, a floating dock, and workspace-first navigation. It is its own design;
Pantheon settings and applications are not migrated.

## Preview in a VM

```sh
nix build .#vm --out-link result-vm
./result-vm/bin/run-wayfire-studio-vm
```

The x86_64 VM opens a GTK window and signs in automatically. It uses 4 CPU cores,
4 GiB RAM, a sparse 16 GiB disk, and accelerated VirtIO graphics. Its demo account
and lock-screen password are both `studio`. Power it off with `sudo poweroff` in
the guest terminal, then rebuild and launch again to test source changes.
The disk persists as `wayfire-studio.qcow2` in the launch directory.

The VM module uses a disposable account with passwordless sudo. Import only the
desktop module on real machines. The guest uses NixOS's default VM store sharing:
the host Nix store is readable, and temporary exchange directories are writable.
It does not mount your home directory. This is a development VM, not a sandbox for
untrusted software.

## Controls

`Super` is the Windows/logo key. Click inside the VM to direct input there; QEMU's
input grab is toggled with Ctrl+Alt+G if the host intercepts shortcuts.

| Shortcut | Action |
| --- | --- |
| Super+Space | Application launcher |
| Super+Enter | Terminal |
| Super+P | Choose a profile |
| Super+T | Toggle the focused window's membership in the tiling layout |
| Super+H/J/K/L | Focus adjacent tiled windows |
| Super+Left/Right | Snap a floating window to half the screen |
| Super+Up / Down | Maximize / restore a floating window |
| Super+E | Workspace overview |
| Super+Ctrl+Left/Right | Change workspace; add Shift to carry a window |
| Super+left/right mouse drag | Move / resize windows, including tiles |
| Super+F | Fullscreen |
| Super+Q | Close the focused window |
| Super+Shift+L | Lock |
| Print | Select a screenshot region and copy it to the clipboard |

The mode label in the status bar opens the mode picker. Super+Shift+Space opens
the Soltros command center for quick actions.

The dock's **+** button opens **Add to Dock**. Search for any installed desktop
application and check it to pin it; uncheck it to remove the pin. Right-clicking a
pinned icon also opens this manager. Launch commands come from the application's
desktop entry, including its argument handling. Pins are saved in
`~/.local/state/wayfire-studio/pins.json`.

The square grid button opens **Background Apps**, a popup for applications that
publish a StatusNotifier tray icon. Click an app to activate it, or use its menu
button for app-specific actions such as Quit. Click away or press Escape to hide
the popup. It does not enumerate arbitrary background processes. The same control
is available on the panel when using Focus mode.

The top status bar is always opaque. It combines icon-based application launch,
file manager, CPU, RAM, disk, network, audio,
media, tray, battery, clock, workspace, and mode controls. Media can be toggled
with left click and skipped with middle/right click. Papirus Dark is the icon theme for the dock,
taskbar, popup, application picker, and GTK applications. Starting the session sets
the user's GNOME interface icon-theme preference to `Papirus-Dark`.
The unified top panel appears on both outputs and shows each display's running
windows. Tray and background-app controls live in that panel only.
If a bar fails to start, session diagnostics are written to
`$XDG_RUNTIME_DIR/wayfire-studio/shell.log`.
The session starts one Waybar process for all bars on all connected monitors.
The packaged Waybar disables GTK application uniqueness to prevent an existing
session-bus application from swallowing startup. Successful startup logs contain
`Bar configured` for each output; flake evaluation alone does not test rendering.
Static Papirus images use `interval = "once"`: Waybar 0.15 otherwise reloads
them every millisecond, starving redraws and leaving an apparently empty desktop.

| Mode | Behavior |
| --- | --- |
| Focus | Minimal workspace with floating windows and maximum screen space |
| Tiled | Automatic tiling for a terminal-first grid workflow |
| Layout | Floating windows with sidebar-oriented navigation |
| Nix Shell | Automatic tiling for a command-line-first workflow |
| Floaters | Freeform floating utility layout |
| Game | Fullscreen-friendly distraction-free layout |
| Classic / Compact | Compatibility profiles retained during development |

Changing profiles reloads configuration without logging out. Tiling defaults apply
to **new** windows; use Super+T for existing windows. Your chosen profile persists.
Wayfire's simple-tile is a basic tiling engine, not a complete i3/Sway command model.

## Use the module later

For local development, add this input to your system flake:

```nix
inputs.wayfire-studio = {
  url = "path:/home/derrik/wayfire-studio";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Include `inputs.wayfire-studio.nixosModules.default` in your machine's modules:

```nix
desktop.wayfireStudio = {
  enable = true;
  defaultProfile = "classic";
  extraSettings = {
    input.xkb_layout = "us";
    "output:eDP-1".scale = 1.25;
  };
};
```

The module registers **Wayfire Studio** with your display manager. It supplies
Wayland portals, XWayland support, Polkit support, and the screen-lock PAM service
through NixOS's Wayfire module. Your machine supplies its display manager, audio,
networking, and optional removable-media services. The VM shows those integrations.
The flake is published at [soltros/wayfire-studio](https://github.com/soltros/wayfire-studio).

## Development

- `package.nix`: generated Wayfire modes, shell bars, and session package
- `style.css`, `launcher.css`, `wallpaper.svg`: visual design
- `scripts/`: session lifecycle, launcher, profile switching, screenshots
- `modules/nixos.nix`: reusable module and options
- `vm.nix`: isolated preview machine, including VM-only cursor workaround

```sh
nix flake check
nix build .#vm
nix shell nixpkgs#shellcheck -c shellcheck scripts/*.sh
```

Upstream references: [Wayfire configuration](https://github.com/WayfireWM/wayfire/blob/v0.10.1/wayfire.ini),
[tiling options](https://github.com/WayfireWM/wayfire/blob/v0.10.1/metadata/simple-tile.xml),
[VirtIO cursor rendering issue](https://gitlab.com/qemu-project/qemu/-/issues/2315).
