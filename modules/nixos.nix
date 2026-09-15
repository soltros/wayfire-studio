{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.wayfireStudio;
  desktop = pkgs.callPackage ../package.nix {
    inherit (cfg) defaultProfile extraSettings;
  };
in
{
  options.desktop.wayfireStudio = {
    enable = lib.mkEnableOption "the Wayfire Studio desktop session";
    defaultProfile = lib.mkOption {
      type = lib.types.enum [
        "classic"
        "focus"
        "compact"
      ];
      default = "classic";
      description = "Initial layout; the session remembers subsequent profile changes.";
    };
    extraSettings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (
          attrsOf (oneOf [
            str
            int
            float
            bool
          ])
        );
      default = { };
      example = {
        input.xkb_layout = "us";
        "output:eDP-1".scale = 1.5;
      };
      description = "Wayfire INI overrides applied to every profile.";
    };
  };
  config = lib.mkIf cfg.enable {
    programs.wayfire.enable = true;
    systemd.user.targets.wayfire-studio-session = {
      description = "Wayfire Studio graphical session";
      bindsTo = [ "graphical-session.target" ];
      before = [ "graphical-session.target" ];
    };
    services.displayManager.sessionPackages = [ desktop ];
    environment.systemPackages = [
      desktop
      pkgs.wdisplays
      pkgs.pavucontrol
    ];
    fonts.packages = [
      pkgs.inter
      pkgs.font-awesome
    ];
    xdg.portal.config.wayfire = {
      default = [
        "wlr"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };
}
