{
  config,
  lib,
  pkgs,
  ...
}:

with pkgs.lib.ordenada;

let
  inherit (lib)
    mkOption
    mkIf
    mkMerge
    types
    ;
  features = config.ordenada.features;
  cfg = features.home;
in
{
  options = {
    ordenada.features.home = {
      enable = mkEnableTrueOption "the home feature";
      extraGroups = mkOption {
        type = types.listOf types.str;
        description = "The extra list of groups.";
        default = [ ];
      };
      autoStartWmOnTty = mkOption {
        type = types.nullOr types.str;
        description = "The tty to launch the WM in.";
        default = null;
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.enable (mkMerge [
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
      }
      (mkIf (config.ordenada.globals.isLinux == true) {
        ## Starting the chosen wm on the desired tty if enabled
        environment.loginShellInit = mkIf (cfg.autoStartWmOnTty != null) ''
          [[ $(tty) == ${cfg.autoStartWmOnTty} ]] && exec ${config.ordenada.globals.wm}
        '';
      })
    ]))
    {
      home-manager = mkHomeConfig config "home" (user: {
        programs.home-manager.enable = true;
        targets.genericLinux.enable = config.ordenada.globals.isLinux == true;
        home.stateVersion = "24.05";

        ## If the user isn't using any of the shell modules, add the session-vars to .profile
        ## ourselves so other modules work properly
        home.file.".profile".text = mkIf (config.ordenada.globals.shell == null) (builtins.trace config.home-manager.users.${user.name}.home.profileDirectory ''
          . "${config.home-manager.users.${user.name}.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
        '');
      });

      users = mkMerge [
        (mkIf (config.ordenada.globals.isLinux == true) (
          mkHomeConfig config "home" (user: {
            isNormalUser = true;
            extraGroups = [ "wheel" ] ++ user.features.home.extraGroups;
          })
        ))
        (mkIf (config.ordenada.globals.isDarwin == true) (
          mkHomeConfig config "home" (user: {
            home = features.userInfo.homeDirectory;
          })
        ))
      ];
    }
  ];
}
