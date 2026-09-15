{ pkgs }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "wayfire-studio-background-apps";
  version = "0.1.0";
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
  buildInputs = [ pkgs.gtk3 pkgs.gtk-layer-shell pkgs.libdbusmenu-gtk3 ];
  installPhase = ''
    install -Dm755 ${./scripts/background-apps.py} $out/bin/wayfire-studio-background-apps
    install -Dm755 ${./scripts/dock.py} $out/bin/wayfire-studio-dock
    substituteInPlace $out/bin/wayfire-studio-background-apps \
      --replace-fail '#!/usr/bin/env python3' '#!${pkgs.python3.withPackages (p: [ p.pygobject3 ])}/bin/python3'
    substituteInPlace $out/bin/wayfire-studio-dock \
      --replace-fail '#!/usr/bin/env python3' '#!${pkgs.python3.withPackages (p: [ p.pygobject3 ])}/bin/python3'
    gappsWrapperArgs+=(--prefix XDG_DATA_DIRS : ${pkgs.papirus-icon-theme}/share)
  '';
}
