{
  description = "Wayfire Studio — a Pantheon-inspired, adaptable NixOS desktop";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      nixosModules.default = import ./modules/nixos.nix;
      nixosModules.wayfire-studio = self.nixosModules.default;
      nixosConfigurations.studio-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.default
          ./vm.nix
        ];
      };
      packages = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = self.packages.${system}.wayfire-studio;
          wayfire-studio = pkgs.callPackage ./package.nix { };
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          vm = self.nixosConfigurations.studio-vm.config.system.build.vm;
        }
      );
      apps = eachSystem (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/wayfire-studio";
        };
      });
      formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt);
      checks = eachSystem (system: {
        package = self.packages.${system}.default;
        module =
          let
            evaluated = nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                self.nixosModules.default
                ({ ... }: {
                  desktop.wayfireStudio.enable = true;
                  system.stateVersion = "26.05";
                  boot.loader.grub.enable = false;
                  fileSystems."/" = {
                    device = "/dev/test";
                    fsType = "ext4";
                  };
                })
              ];
            };
          in
          assert evaluated.config.programs.wayfire.enable;
          assert evaluated.config.security.polkit.enable;
          assert evaluated.config.security.pam.services ? swaylock;
          assert builtins.all (a: a.assertion) evaluated.config.assertions;
          nixpkgs.legacyPackages.${system}.writeText "wayfire-studio-module-check" "ok";
      });
    };
}
