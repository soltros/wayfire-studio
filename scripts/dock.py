#!/usr/bin/env python3
"""Persistent app pinning and Papirus icon resolution for the Studio dock."""
import json
import os
from pathlib import Path
import shlex
import signal
import sys
import tempfile
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gio, Gtk

state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "wayfire-studio"
runtime = Path(os.environ.get("WAYFIRE_STUDIO_RUNTIME", Path(os.environ["XDG_RUNTIME_DIR"]) / "wayfire-studio"))
state.mkdir(parents=True, exist_ok=True)
pins_file = state / "pins.json"


def apps():
    return sorted((app for app in Gio.AppInfo.get_all() if app.should_show() and app.get_id()),
                  key=lambda app: app.get_display_name().lower())


def pins():
    if pins_file.exists():
        return json.loads(pins_file.read_text())
    defaults = []
    available = apps()
    for wanted in ("foot", "thunar", "firefox"):
        match = next((app for app in available if wanted in app.get_id().lower()), None)
        if match:
            defaults.append(match.get_id())
    return defaults


def atomic_json(path, value):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as handle:
        json.dump(value, handle)
        temporary = handle.name
    os.replace(temporary, path)


def reload_bar():
    try:
        pid = int((runtime / "waybar.pid").read_text())
        args = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
        if str(runtime / "waybar.json").encode() in args:
            os.kill(pid, signal.SIGUSR2)
    except (OSError, ValueError):
        pass


def render(base):
    # GTK's icon theme lookup works without opening a display.
    theme = Gtk.IconTheme.new()
    theme.set_custom_theme("Papirus-Dark")
    config = json.loads(Path(base).read_text())

    def icon_file(icon):
        if icon:
            info = theme.lookup_by_gicon(icon, 32, Gtk.IconLookupFlags.FORCE_SIZE)
            if info:
                return info.get_filename()
        info = theme.lookup_icon("application-x-executable", 32, 0)
        return info.get_filename() if info else ""

    def image(bar, name, icon, action, right_action=None, size=28):
        key = "image#" + name
        bar[key] = {"path": icon_file(icon), "size": size, "interval": "once", "on-click": action}
        if right_action:
            bar[key]["on-click-right"] = right_action
        return key

    for bar in config:
        if bar.get("name") != "dock":
            # Keep the background-app control reachable in Focus mode too.
            key = image(bar, "background", Gio.ThemedIcon.new("view-grid-symbolic"),
                        "wayfire-studio-background-apps toggle", size=18)
            bar.setdefault("modules-right", []).insert(0, key)
            continue
        modules = [image(bar, "applications", Gio.ThemedIcon.new("view-app-grid"), "wayfire-studio-launcher")]
        for index, desktop_id in enumerate(pins()):
            app = Gio.DesktopAppInfo.new(desktop_id)
            if app:
                modules.append(image(bar, f"pin{index}", app.get_icon(),
                    "wayfire-studio-dock launch " + shlex.quote(desktop_id),
                    "wayfire-studio-dock manage"))
        modules.append("wlr/taskbar")
        modules.append(image(bar, "workspaces", Gio.ThemedIcon.new("view-list-icons"),
                             "wayfire-studio-workspaces view", "wayfire-studio-workspaces manage"))
        modules.append(image(bar, "background", Gio.ThemedIcon.new("view-grid-symbolic"),
                             "wayfire-studio-background-apps toggle"))
        modules.append(image(bar, "add", Gio.ThemedIcon.new("list-add"), "wayfire-studio-dock manage"))
        bar["modules-center"] = modules
    atomic_json(runtime / "waybar.json", config)
    (runtime / "bar-base").write_text(str(base))


def manage():
    Gtk.Settings.get_default().set_property("gtk-icon-theme-name", "Papirus-Dark")
    window = Gtk.Window(title="Add to Dock")
    window.set_default_size(460, 520)
    window.connect("destroy", Gtk.main_quit)
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin=16)
    box.pack_start(Gtk.Label(label="Choose apps to keep in your dock", xalign=0), False, False, 0)
    search = Gtk.SearchEntry(placeholder_text="Search applications…")
    box.pack_start(search, False, False, 0)
    scroll = Gtk.ScrolledWindow()
    listing = Gtk.ListBox()
    listing.set_selection_mode(Gtk.SelectionMode.NONE)
    chosen = pins()

    def changed(button, desktop_id):
        if button.get_active() and desktop_id not in chosen:
            chosen.append(desktop_id)
        elif not button.get_active() and desktop_id in chosen:
            chosen.remove(desktop_id)
        atomic_json(pins_file, chosen)
        render((runtime / "bar-base").read_text())
        reload_bar()

    for app in apps():
        row = Gtk.ListBoxRow()
        row.search_text = (app.get_display_name() + " " + app.get_id()).lower()
        line = Gtk.Box(spacing=12, margin=5)
        icon = Gtk.Image.new_from_gicon(app.get_icon() or Gio.ThemedIcon.new("application-x-executable"), Gtk.IconSize.LARGE_TOOLBAR)
        check = Gtk.CheckButton(label=app.get_display_name())
        check.set_active(app.get_id() in chosen)
        check.connect("toggled", changed, app.get_id())
        line.pack_start(icon, False, False, 0)
        line.pack_start(check, True, True, 0)
        row.add(line)
        listing.add(row)
    listing.set_filter_func(lambda row: search.get_text().lower() in row.search_text)
    search.connect("search-changed", lambda *_: listing.invalidate_filter())
    scroll.add(listing)
    box.pack_start(scroll, True, True, 0)
    box.pack_start(Gtk.Label(label="Checked apps stay pinned. Uncheck to remove."), False, False, 0)
    window.add(box)
    window.show_all()
    Gtk.main()


if __name__ == "__main__":
    if sys.argv[1] == "render":
        render(sys.argv[2])
    elif sys.argv[1] == "manage":
        manage()
    elif sys.argv[1] == "launch":
        app = Gio.DesktopAppInfo.new(sys.argv[2])
        if app:
            app.launch([], None)
