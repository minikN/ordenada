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
  isDarwinPred =
    lib.strings.hasPrefix "x86_64-darwin" system || lib.strings.hasPrefix "aarch64-darwin" system;

  isDarwin = if isDarwinPred == "1" then true else false;
in
{
  imports = [
    ./base.nix
    ./home.nix
    ./git.nix
    ./xdg.nix

    ./security
    ./shell
    
    ./system/fontutils.nix
    ./system/keyboard.nix
    
    ./terminal
  ]
  ++ lib.optionals (isLinux) [
    ./browser
    ./development
    ./editor
    ./messaging
    ./lang
    ./scripts
    ./system
    ./virtualization
    ./wm

    ./gtk.nix
    ./mail.nix
    ./playerctl.nix
    ./tailscale.nix
    ./theme.nix
  ]
  ++ lib.optionals (isDarwin == "1") [ ];
}
