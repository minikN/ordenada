{
  config,
  lib,
  pkgs,
  ...
}:

with pkgs.lib.ordenada;

let
  inherit (lib) types mkOption mkEnableOption;
in
{
  imports = [
    ./alacritty.nix
  ];
  options = {
    ordenada.globals.terminal = mkOption {
      type = types.nullOr types.str;
      description = "The system wide used terminal.";
      default = null;
    };
  };

  config = lib.mkIf config.globals.ordenada.terminal {
    home-manager = mkHomeConfig config "term" (user: {
      home.sessionVariables = {
        TERMINAL = config.ordenada.terminal;
        TERM = config.ordenada.globals.terminal;
      };
    });
  };
}
