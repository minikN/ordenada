{
  lib,
  config,
  pkgs,
  system ? builtins.currentSystem,
  ...
}:

let
  inherit (lib) types mkOption;

  isLinuxPred =
    lib.strings.hasPrefix "x86_64-linux" system || lib.strings.hasPrefix "aarch64-linux" system;
  isDarwinPred =
    lib.strings.hasPrefix "x86_64-darwin" system || lib.strings.hasPrefix "aarch64-darwin" system;

    isDarwin = if isDarwinPred == "1" then true else false;
    isLinux = if isLinuxPred == "1" then true else false;
in
{
  imports = [
    ./base.nix
    ./home.nix
    ./shell
  ]
  ++ lib.optionals (isLinux == "1") [
    ./browser
    ./development
    ./editor
    ./messaging
    ./lang
    ./scripts
    ./security
    ./system
    ./virtualization
    ./wm

    ./git.nix
    ./gtk.nix
    ./mail.nix
    ./playerctl.nix
    ./tailscale.nix
    ./theme.nix
    ./xdg.nix
  ]
  ++ lib.optionals (isDarwin == "1") [ ];

  options = {
    ordenada.globals.isLinux = mkOption {
      type = types.bool;
      description = "Whether ordenada is running under linux.";
      default = isLinuxPred;
    };
    ordenada.globals.isDarwin = mkOption {
      type = types.bool;
      description = "Whether ordenada is running under macOS.";
      default = isDarwinPred;
    };
  };
}
