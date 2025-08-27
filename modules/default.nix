{
  lib,
  config,
  pkgs,
  system ? builtins.currentSystem,
  ...
}:

let
  inherit (lib) types mkOption;

  isLinux =
    lib.strings.hasPrefix "x86_64-linux" system || lib.strings.hasPrefix "aarch64-linux" system;
  isDarwin =
    lib.strings.hasPrefix "x86_64-darwin" system || lib.strings.hasPrefix "aarch64-darwin" system;
in
{
  imports = [
    ./base.nix
    ./home.nix
    ./git.nix
    ./theme.nix
    ./xdg.nix

    ./development
    ./editor
    ./lang
    ./security
    ./shell

    ./system/fontutils.nix
    ./system/keyboard.nix

    ./wm
    ./terminal
  ]
  ++ lib.optionals (isLinux) [
    ./browser
    ./messaging
    ./scripts
    ./system
    ./virtualization

    ./gtk.nix
    ./mail.nix
    ./playerctl.nix
    ./tailscale.nix
  ]
  ++ lib.optionals (isDarwin) [
    ./package-management/homebrew.nix
  ];
}
