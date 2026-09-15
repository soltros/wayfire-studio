{
  pkgs,
  lib,
  defaultProfile ? "classic",
  extraSettings ? { },
}:
let
  ini = pkgs.formats.ini { };
  backgroundApps = pkgs.callPackage ./background-apps.nix { };
  compositor = pkgs.wayfire-with-plugins.override { plugins = [ ]; };
  base = {
    core = {
      plugins = "animate autostart command decoration expo fast-switcher foreign-toplevel grid gtk-shell ipc ipc-rules move oswitch place resize scale session-lock shortcuts-inhibit simple-tile switcher vswitch window-rules wm-actions";
      vwidth = 4;
      vheight = 1;
      preferred_decoration_mode = "client";
      close_top_view = "<super> KEY_Q | <alt> KEY_F4";
    };
    autostart = {
      autostart_wf_shell = false;
      studio = "wayfire-studio-shell";
    };
    input = {
      xkb_layout = "us";
      tap_to_click = true;
    };
    move.activate = "<super> BTN_LEFT";
    resize.activate = "<super> BTN_RIGHT";
    expo.toggle = "<super> KEY_E";
    switcher = {
      next_view = "<alt> KEY_TAB";
      prev_view = "<alt> <shift> KEY_TAB";
    };
    grid = {
      slot_l = "<super> KEY_LEFT";
      slot_r = "<super> KEY_RIGHT";
      slot_c = "<super> KEY_UP";
      restore = "<super> KEY_DOWN";
    };
    vswitch = {
      binding_left = "<super> <ctrl> KEY_LEFT";
      binding_right = "<super> <ctrl> KEY_RIGHT";
      with_win_left = "<super> <ctrl> <shift> KEY_LEFT";
      with_win_right = "<super> <ctrl> <shift> KEY_RIGHT";
    };
    oswitch = {
      next_output = "<super> KEY_O";
      next_output_with_win = "<super> <shift> KEY_O";
    };
    "wm-actions".toggle_fullscreen = "<super> KEY_F";
    "simple-tile" = {
      tile_by_default = "none";
      key_toggle = "<super> KEY_T";
      key_focus_left = "<super> KEY_H";
      key_focus_below = "<super> KEY_J";
      key_focus_above = "<super> KEY_K";
      key_focus_right = "<super> KEY_L";
      inner_gap_size = 8;
      outer_horiz_gap_size = 12;
      outer_vert_gap_size = 12;
    };
    command = {
      binding_terminal = "<super> KEY_ENTER";
      command_terminal = "foot";
      binding_launcher = "<super> KEY_SPACE";
      command_launcher = "wayfire-studio-launcher";
      binding_command_center = "<super> <shift> KEY_SPACE";
      command_command_center = "wayfire-studio-command-center";
      binding_profile = "<super> KEY_P";
      command_profile = "wayfire-studio-profile";
      binding_files = "<super> <shift> KEY_F";
      command_files = "thunar";
      binding_lock = "<super> <shift> KEY_L";
      command_lock = "swaylock -c 171c2b";
      binding_screenshot = "KEY_PRINT";
      command_screenshot = "wayfire-studio-screenshot";
      repeatable_binding_volume_up = "KEY_VOLUMEUP";
      command_volume_up = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
      repeatable_binding_volume_down = "KEY_VOLUMEDOWN";
      command_volume_down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
      binding_mute = "KEY_MUTE";
      command_mute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      repeatable_binding_brightness_up = "KEY_BRIGHTNESSUP";
      command_brightness_up = "brightnessctl set +5%";
      repeatable_binding_brightness_down = "KEY_BRIGHTNESSDOWN";
      command_brightness_down = "brightnessctl set 5%-";
    };
  };
  profiles = lib.genAttrs [ "classic" "focus" "tiled" "layout" "nix-shell" "floaters" "game" "compact" ] (
    name:
    ini.generate "wayfire-${name}.ini" (
      lib.recursiveUpdate (lib.recursiveUpdate base (
        if name == "focus" || name == "layout" || name == "floaters" then
          {
            "simple-tile".tile_by_default = "none";
          }
        else if name == "tiled" || name == "nix-shell" then
          { "simple-tile".tile_by_default = "all"; }
        else if name == "compact" then
          {
            "simple-tile" = {
              inner_gap_size = 3;
              outer_horiz_gap_size = 4;
              outer_vert_gap_size = 4;
            };
          }
        else
          { }
      )) extraSettings
    )
  );
  configs = pkgs.linkFarm "wayfire-studio-profiles" (
    lib.mapAttrsToList (name: path: {
      name = "${name}.ini";
      inherit path;
    }) profiles
  );
  bars = [
    {
      name = "panel";
      layer = "top";
      position = "bottom";
      height = 34;
      margin = "0";
      "modules-left" = [
        "custom/brand"
        "custom/applications"
        "custom/profile"
        "custom/workspaces"
        "custom/command"
      ];
      "modules-center" = [ "clock" ];
      "modules-right" = [
        "cpu"
        "memory"
        "disk#root"
        "network"
        "pulseaudio"
        "tray"
        "battery"
        "custom/lock"
      ];
      "custom/applications" = {
        format = "󰣪";
        "on-click" = "wayfire-studio-launcher";
        tooltip = false;
      };
      "custom/brand" = {
        format = "󰣇  Soltros";
        tooltip = false;
      };
      "custom/profile" = {
        exec = "wayfire-studio-profile status";
        interval = 2;
        "on-click" = "wayfire-studio-profile";
        tooltip = false;
      };
      "custom/workspaces" = {
        format = "󰍹  {}";
        exec = "wayfire-studio-workspaces status";
        interval = 2;
        "on-click" = "wayfire-studio-workspaces view";
        "on-click-right" = "wayfire-studio-workspaces manage";
        tooltip = false;
      };
      "custom/command" = {
        format = "󰘳";
        "on-click" = "wayfire-studio-command-center";
        tooltip = false;
      };
      clock = {
        format = "{:%a, %b %d  ·  %H:%M}";
        "tooltip-format" = "<tt>{calendar}</tt>";
      };
      network = {
        "format-wifi" = "Wi-Fi · {essid}";
        "format-ethernet" = "Wired";
        "format-disconnected" = "Offline";
        "on-click" = "nm-connection-editor";
      };
      pulseaudio = {
        format = "Audio · {volume}%";
        "format-muted" = "Muted";
        "on-click" = "pavucontrol";
      };
      cpu = {
        format = "CPU {usage}%";
        "format-alt" = "CPU {usage}% · {load}";
        interval = 5;
      };
      memory = {
        format = "RAM {percentage}%";
        interval = 5;
      };
      "disk#root" = {
        format = "Disk {percentage_used}%";
        path = "/";
        interval = 30;
      };
      battery = {
        format = "{capacity}%";
        states = {
          warning = 25;
          critical = 10;
        };
      };
      "custom/lock" = {
        format = "Lock";
        "on-click" = "swaylock -c 171c2b";
        tooltip = false;
      };
    }
    {
      name = "sidebar";
      layer = "top";
      position = "left";
      width = 64;
      "modules-left" = [
        "custom/side-apps"
        "custom/side-files"
        "custom/side-browser"
        "custom/side-code"
        "custom/side-media"
        "custom/side-settings"
      ];
      "custom/side-apps" = { format = "󰀻"; "on-click" = "wayfire-studio-launcher"; tooltip = false; };
      "custom/side-files" = { format = "󰉋"; "on-click" = "thunar"; tooltip = false; };
      "custom/side-browser" = { format = "󰖟"; "on-click" = "firefox"; tooltip = false; };
      "custom/side-code" = { format = "󰨞"; "on-click" = "foot"; tooltip = false; };
      "custom/side-media" = { format = "󰝚"; "on-click" = "pavucontrol"; tooltip = false; };
      "custom/side-settings" = { format = "󰒓"; "on-click" = "wayfire-studio-profile"; tooltip = false; };
    }
    {
      name = "dock";
      layer = "top";
      position = "bottom";
      "margin-bottom" = 12;
      height = 54;
      width = 460;
      "modules-center" = [
        "custom/launcher"
        "custom/files"
        "custom/terminal"
        "wlr/taskbar"
        "custom/background"
        "custom/add"
      ];
      "custom/launcher" = {
        format = "";
        "on-click" = "wayfire-studio-launcher";
        tooltip = false;
      };
      "custom/files" = {
        format = "";
        "on-click" = "thunar";
        tooltip = false;
      };
      "custom/terminal" = {
        format = "";
        "on-click" = "foot";
        tooltip = false;
      };
      "wlr/taskbar" = {
        "icon-theme" = "Papirus-Dark";
        format = "{icon}";
        "icon-size" = 28;
        "on-click" = "activate";
        "on-click-middle" = "close";
        "tooltip-format" = "{title}";
      };
    }
  ];
  barProfiles = pkgs.linkFarm "wayfire-studio-bars" (
    map
      (name: {
        name = "${name}.json";
        path = pkgs.writeText "waybar-${name}.json" (
          builtins.toJSON (
            if name == "compact" then
              [
                (builtins.head bars)
                (
                  (builtins.elemAt bars 1)
                  // {
                    height = 38;
                    width = 360;
                    "margin-bottom" = 4;
                  }
                )
              ]
            else
              bars
          )
        );
      })
      [
        "classic"
        "focus"
        "tiled"
        "layout"
        "nix-shell"
        "floaters"
        "game"
        "compact"
      ]
  );
  runtime = with pkgs; [
    backgroundApps
    papirus-icon-theme
    python3
    coreutils
    gnugrep
    util-linux
    waybar
    wofi
    foot
    thunar
    swaybg
    mako
    swaylock
    swayidle
    grim
    slurp
    wl-clipboard
    wireplumber
    brightnessctl
    networkmanagerapplet
    pavucontrol
    dbus
    systemd
    libnotify
    polkit_gnome
    wdisplays
    adwaita-icon-theme
  ];
  scripts = pkgs.writeShellApplication {
    name = "wayfire-studio";
    runtimeInputs = runtime ++ [ compositor ];
    text = ''
      export XDG_CURRENT_DESKTOP=wayfire
      export XDG_SESSION_DESKTOP=wayfire
      export XDG_SESSION_TYPE=wayland
      export GTK_THEME=Adwaita:dark
      export XDG_DATA_DIRS="${lib.makeSearchPath "share" runtime}:''${XDG_DATA_DIRS:-/run/current-system/sw/share}"
      export WAYFIRE_STUDIO_RUNTIME="''${XDG_RUNTIME_DIR:?A login session with XDG_RUNTIME_DIR is required}/wayfire-studio"
      mkdir -p "$WAYFIRE_STUDIO_RUNTIME"
      chmod 700 "$WAYFIRE_STUDIO_RUNTIME"
      exec 9>"$WAYFIRE_STUDIO_RUNTIME/session.lock"
      flock -n 9 || { echo 'Wayfire Studio is already running.' >&2; exit 1; }
      export PATH="@out@/bin:$PATH"
      wayfire-studio-profile init
      exec wayfire -c "$WAYFIRE_STUDIO_RUNTIME/wayfire.ini"
    '';
  };
in
pkgs.symlinkJoin {
  name = "wayfire-studio-0.1.0";
  paths = [ scripts ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    rm "$out/bin/wayfire-studio"
    substitute ${scripts}/bin/wayfire-studio "$out/bin/wayfire-studio" --replace-fail '@out@' "$out"
    chmod +x "$out/bin/wayfire-studio"
    install -Dm755 ${./scripts/profile.sh} "$out/bin/wayfire-studio-profile"
    install -Dm755 ${./scripts/shell.sh} "$out/bin/wayfire-studio-shell"
    install -Dm755 ${./scripts/screenshot.sh} "$out/bin/wayfire-studio-screenshot"
    install -Dm755 ${./scripts/launcher.sh} "$out/bin/wayfire-studio-launcher"
    install -Dm755 ${./scripts/workspaces.sh} "$out/bin/wayfire-studio-workspaces"
    install -Dm755 ${./scripts/command-center.sh} "$out/bin/wayfire-studio-command-center"
    substituteInPlace "$out/bin/wayfire-studio-launcher" --replace-fail '@style@' '${./launcher.css}'
    substituteInPlace "$out/bin/wayfire-studio-profile" \
      --replace-fail '@profiles@' '${configs}' --replace-fail '@bars@' '${barProfiles}' --replace-fail '@default@' '${defaultProfile}'
    substituteInPlace "$out/bin/wayfire-studio-command-center" \
      --replace-fail '@style@' '${./launcher.css}'
    substituteInPlace "$out/bin/wayfire-studio-shell" \
      --replace-fail '@style@' '${./style.css}' \
      --replace-fail '@wallpaper@' '${./wallpaper.svg}' \
      --replace-fail '@polkit@' '${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1'
    for script in "$out"/bin/wayfire-studio-*; do
      patchShebangs "$script"
      wrapProgram "$script" --prefix PATH : "${lib.makeBinPath runtime}:$out/bin"
    done
    mkdir -p "$out/share/wayland-sessions"
    cat > "$out/share/wayland-sessions/wayfire-studio.desktop" <<EOF
    [Desktop Entry]
    Name=Wayfire Studio
    Comment=Transformable Soltros Wayfire desktop
    Exec=$out/bin/wayfire-studio
    Type=Application
    DesktopNames=wayfire
    EOF
  '';
  passthru.providedSessions = [ "wayfire-studio" ];
  meta = {
    description = "Transformable Soltros Wayfire desktop with multiple modes";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "wayfire-studio";
  };
}
