#!/usr/bin/env python3
"""Small Wayland popup hosting StatusNotifier tray applications."""
import sys
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
gi.require_version("DbusmenuGtk3", "0.4")
from gi.repository import Gio, GLib, Gtk, Gdk, GdkPixbuf, GtkLayerShell, DbusmenuGtk3

WATCHER = "org.kde.StatusNotifierWatcher"
ITEM = "org.kde.StatusNotifierItem"
CONTROL = "org.wayfire.Studio.BackgroundApps"
XML = """<node>
<interface name="org.kde.StatusNotifierWatcher">
  <method name="RegisterStatusNotifierItem"><arg type="s" direction="in"/></method>
  <method name="RegisterStatusNotifierHost"><arg type="s" direction="in"/></method>
  <property name="RegisteredStatusNotifierItems" type="as" access="read"/>
  <property name="IsStatusNotifierHostRegistered" type="b" access="read"/>
  <property name="ProtocolVersion" type="i" access="read"/>
  <signal name="StatusNotifierItemRegistered"><arg type="s"/></signal>
  <signal name="StatusNotifierItemUnregistered"><arg type="s"/></signal>
  <signal name="StatusNotifierHostRegistered"/>
</interface>
<interface name="org.wayfire.Studio.BackgroundApps">
  <method name="Toggle"/>
</interface>
</node>"""


class BackgroundApps:
    def __init__(self):
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        Gtk.Settings.get_default().set_property("gtk-icon-theme-name", "Papirus-Dark")
        self.items = {}
        self.menu = None
        self.last_focus_hide = 0
        self.window = Gtk.Window(title="Background Apps")
        self.window.set_default_size(320, -1)
        self.window.set_resizable(False)
        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, "studio-background-apps")
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.BOTTOM, 84)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.ON_DEMAND)
        self.window.connect("focus-out-event", self.focus_out)
        self.window.connect("key-press-event", self.key_press)
        self.window.connect("delete-event", lambda *_: self.window.hide() or True)
        css = Gtk.CssProvider()
        css.load_from_data(b"""
          window { background: #242c3c; color: #e6eaf2; border: 1px solid #516380; border-radius: 14px; font-family: Inter; }
          .header { padding: 14px 16px 10px; }
          .heading { font-size: 14px; font-weight: bold; }
          .subtitle { font-size: 11px; color: #aab6c9; }
          .app-row { margin: 3px 8px; padding: 8px; border-radius: 8px; }
          .app-row:hover { background: #354765; }
          button { background: transparent; color: #e6eaf2; border: none; box-shadow: none; padding: 6px; }
          button:hover { background: #445976; }
        """)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css, 600)
        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.box.set_margin_bottom(10)
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        header.get_style_context().add_class("header")
        title = Gtk.Label(label="Background Apps", xalign=0)
        title.get_style_context().add_class("heading")
        subtitle = Gtk.Label(label="Apps with a tray icon", xalign=0)
        subtitle.get_style_context().add_class("subtitle")
        header.pack_start(title, False, False, 0)
        header.pack_start(subtitle, False, False, 0)
        self.box.pack_start(header, False, False, 0)
        self.box.pack_start(Gtk.Separator(), False, False, 0)
        self.rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.box.pack_start(self.rows, True, True, 0)
        self.window.add(self.box)
        info = Gio.DBusNodeInfo.new_for_xml(XML)
        self.bus.register_object("/StatusNotifierWatcher", info.interfaces[0], self.method, self.property, None)
        self.bus.register_object("/org/wayfire/Studio/BackgroundApps", info.interfaces[1], self.method, None, None)
        self.owners = [
            Gio.bus_own_name_on_connection(self.bus, WATCHER, Gio.BusNameOwnerFlags.NONE, None, self.name_lost),
            Gio.bus_own_name_on_connection(self.bus, CONTROL, Gio.BusNameOwnerFlags.NONE, None, self.name_lost),
        ]
        self.refresh()

    def name_lost(self, _bus, name):
        print(f"Cannot own {name}; another tray host may already be running.", file=sys.stderr)
        Gtk.main_quit()

    def method(self, _bus, sender, _path, interface, method, parameters, invocation):
        if interface == CONTROL:
            self.toggle()
        elif method == "RegisterStatusNotifierItem":
            value = parameters.unpack()[0]
            service, path = (sender, value) if value.startswith("/") else (value, "/StatusNotifierItem")
            self.register(service, path)
        elif method == "RegisterStatusNotifierHost":
            self.emit("StatusNotifierHostRegistered")
        invocation.return_value(None)

    def property(self, _bus, _sender, _path, _interface, name):
        if name == "RegisteredStatusNotifierItems":
            return GLib.Variant("as", list(self.items))
        if name == "IsStatusNotifierHostRegistered":
            return GLib.Variant("b", True)
        return GLib.Variant("i", 0)

    def emit(self, name, key=None):
        self.bus.emit_signal(None, "/StatusNotifierWatcher", WATCHER, name,
                             GLib.Variant("(s)", (key,)) if key else None)

    def register(self, service, path):
        key = service + path
        if key in self.items:
            return
        self.items[key] = {"service": service, "path": path, "props": {}}
        self.items[key]["watch"] = Gio.bus_watch_name_on_connection(
            self.bus, service, Gio.BusNameWatcherFlags.NONE, None,
            lambda *_: self.remove(key))
        self.items[key]["signal"] = self.bus.signal_subscribe(
            service, None, None, path, None, Gio.DBusSignalFlags.NONE,
            lambda *_: self.fetch(key))
        self.emit("StatusNotifierItemRegistered", key)
        self.fetch(key)

    def fetch(self, key):
        if key not in self.items:
            return
        item = self.items[key]
        self.bus.call(item["service"], item["path"], "org.freedesktop.DBus.Properties", "GetAll",
                      GLib.Variant("(s)", (ITEM,)), GLib.VariantType.new("(a{sv})"),
                      Gio.DBusCallFlags.NONE, 2000, None, self.fetched, key)

    def fetched(self, connection, result, key):
        try:
            properties = connection.call_finish(result).unpack()[0]
        except GLib.Error:
            return
        if key in self.items:
            self.items[key]["props"] = properties
            self.refresh()

    def remove(self, key):
        item = self.items.pop(key, None)
        if item:
            Gio.bus_unwatch_name(item["watch"])
            self.bus.signal_unsubscribe(item["signal"])
            self.emit("StatusNotifierItemUnregistered", key)
            self.refresh()

    def icon(self, properties):
        name = properties.get("IconName", "")
        theme_path = properties.get("IconThemePath", "")
        theme = Gtk.IconTheme.new()
        theme.set_custom_theme("Papirus-Dark")
        if theme_path:
            theme.append_search_path(theme_path)
        if name:
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(name, 28, 28, True) if name.startswith("/") else theme.load_icon(name, 28, 0)
                return Gtk.Image.new_from_pixbuf(pixbuf)
            except GLib.Error:
                pass
        pixmaps = properties.get("IconPixmap", [])
        if pixmaps:
            width, height, data = min(pixmaps, key=lambda p: abs(p[0] - 28))
            if 0 < width <= 512 and 0 < height <= 512 and len(data) == width * height * 4:
                rgba = bytearray(data)
                for offset in range(0, len(rgba), 4):
                    a, r, g, b = rgba[offset:offset + 4]
                    rgba[offset:offset + 4] = bytes((r, g, b, a))
                pixbuf = GdkPixbuf.Pixbuf.new_from_bytes(GLib.Bytes.new(bytes(rgba)),
                    GdkPixbuf.Colorspace.RGB, True, 8, width, height, width * 4)
                return Gtk.Image.new_from_pixbuf(pixbuf.scale_simple(28, 28, GdkPixbuf.InterpType.BILINEAR))
        return Gtk.Image.new_from_icon_name("application-x-executable", Gtk.IconSize.LARGE_TOOLBAR)

    def refresh(self):
        for child in self.rows.get_children():
            child.destroy()
        for key, item in self.items.items():
            props = item["props"]
            row = Gtk.Box(spacing=8)
            row.get_style_context().add_class("app-row")
            activate = Gtk.Button()
            content = Gtk.Box(spacing=10)
            content.pack_start(self.icon(props), False, False, 0)
            label = Gtk.Label(label=props.get("Title") or props.get("Id") or item["service"], xalign=0)
            label.set_max_width_chars(28)
            label.set_ellipsize(3)
            content.pack_start(label, True, True, 0)
            activate.add(content)
            activate.connect("clicked", lambda _button, k=key: self.activate(k))
            row.pack_start(activate, True, True, 0)
            menu = Gtk.Button(label="⋮")
            menu.set_tooltip_text("App menu")
            menu.connect("clicked", lambda button, k=key: self.context(k, button))
            row.pack_end(menu, False, False, 0)
            self.rows.pack_start(row, False, False, 0)
        if not self.items:
            empty = Gtk.Label(label="No background apps", margin=18)
            self.rows.pack_start(empty, False, False, 0)
        self.rows.show_all()

    def activate(self, key):
        item = self.items.get(key)
        if not item:
            return
        if item["props"].get("ItemIsMenu", False):
            self.context(key, self.window)
            return
        self.bus.call(item["service"], item["path"], ITEM, "Activate", GLib.Variant("(ii)", (0, 0)),
                      None, Gio.DBusCallFlags.NONE, 2000, None, None, None)
        self.window.hide()

    def context(self, key, button):
        item = self.items.get(key)
        if not item:
            return
        path = item["props"].get("Menu")
        if path and path != "/":
            self.menu = DbusmenuGtk3.Menu.new(item["service"], path)
            self.menu.connect("deactivate", self.menu_closed)
            self.menu.show_all()
            self.menu.popup_at_widget(button, Gdk.Gravity.NORTH_EAST, Gdk.Gravity.SOUTH_EAST, None)
        else:
            self.bus.call(item["service"], item["path"], ITEM, "ContextMenu", GLib.Variant("(ii)", (0, 0)),
                          None, Gio.DBusCallFlags.NONE, 2000, None, None, None)

    def menu_closed(self, *_):
        self.menu = None

    def focus_out(self, *_):
        if self.menu is None:
            self.window.hide()
            self.last_focus_hide = GLib.get_monotonic_time()
        return False

    def key_press(self, _window, event):
        if event.keyval == Gdk.KEY_Escape:
            self.window.hide()
            return True
        return False

    def toggle(self):
        if GLib.get_monotonic_time() - self.last_focus_hide < 250000:
            return
        if self.window.get_visible():
            self.window.hide()
        else:
            self.window.show_all()
            self.window.present()


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "toggle":
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        bus.call_sync(CONTROL, "/org/wayfire/Studio/BackgroundApps", CONTROL, "Toggle",
                      None, None, Gio.DBusCallFlags.NONE, 2000, None)
    else:
        app = BackgroundApps()
        Gtk.main()
