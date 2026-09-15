{
  config,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
  networking.hostName = "wayfire-studio";
  system.stateVersion = "26.05";
  desktop.wayfireStudio.enable = true;
  desktop.wayfireStudio.extraSettings."output:Virtual-1".mode = "1440x900";
  desktop.wayfireStudio.defaultProfile = "classic";
  virtualisation = {
    memorySize = 4096;
    cores = 4;
    diskSize = 16384;
    resolution = {
      x = 1440;
      y = 900;
    };
    qemu.enableSharedMemory = true;
    qemu.options = [
      "-vga none"
      "-device virtio-vga-gl,xres=1440,yres=900"
      "-display gtk,gl=on,show-cursor=on"
    ];
  };
  hardware.graphics.enable = true;
  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        # VirGL can flip the hardware cursor texture; composite it in the guest.
        command = "${pkgs.coreutils}/bin/env WLR_NO_HARDWARE_CURSORS=1 ${
          pkgs.callPackage ./package.nix {
            inherit (config.desktop.wayfireStudio) defaultProfile extraSettings;
          }
        }/bin/wayfire-studio";
        user = "studio";
      };
      default_session = initial_session;
    };
  };
  users.users.studio = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "video"
      "render"
      "networkmanager"
    ];
    initialPassword = "studio";
  };
  # Disposable demo account; never import this VM module on a real machine.
  security.sudo.wheelNeedsPassword = false;
  networking.networkmanager.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
  };
  security.rtkit.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  programs.dconf.enable = true;
  environment.systemPackages = [
    pkgs.firefox
    pkgs.mousepad
  ];
  time.timeZone = "America/Detroit";
}
