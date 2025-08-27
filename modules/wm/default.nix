{
  config,
  lib,
  pkgs,
  system ? builtins.currentSystem,
  ...
}:

let
  inherit (lib) types mkOption mkEnableOption;

  isLinux =
    lib.strings.hasPrefix "x86_64-linux" system || lib.strings.hasPrefix "aarch64-linux" system;
  isDarwin =
    lib.strings.hasPrefix "x86_64-darwin" system || lib.strings.hasPrefix "aarch64-darwin" system;
in
{
  imports =
    [ ]
    ++ lib.optionals (isLinux) [
      ./bar/waybar.nix
      ./launcher/bemenu.nix
      ./launcher/rofi.nix
      ./kanshi.nix
      ./sway.nix
      ./swaylock.nix
      ./swaync.nix
      ./wlogout.nix
    ]
    ++ lib.optionals (isDarwin) [
      ./aerospace.nix
    ];

  options = {
    ordenada.globals.wayland = mkOption {
      type = types.nullOr types.bool;
      description = "Whether or not the WM is running under wayland.";
      default = false;
    };
    ordenada.globals.wm = mkOption {
      type = types.nullOr types.str;
      description = "The system wide used window manager.";
      default = null;
    };
    ordenada.globals.launcher = mkOption {
      type = types.nullOr types.str;
      description = "The system wide used application launcher.";
      default = null;
    };
    ordenada.globals.bar = mkOption {
      type = types.nullOr types.str;
      description = "The system wide used bar.";
      default = null;
    };
  };
}
