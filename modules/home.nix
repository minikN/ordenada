{
  config,
  lib,
  pkgs,
  options,
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
  ifDarwin = options: attrs: if builtins.hasAttr "launchd" options then attrs else { };
  ifLinux = options: attrs: if !builtins.hasAttr "launchd" options then attrs else { };
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
      ## All platforms
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
        time.timeZone = mkIf (features.userInfo.timezone != null) features.userInfo.timezone;
      }

      ## darwin
      (ifDarwin options (mkMerge [
        {
          environment.variables = mkIf (features.userInfo.defaultLocale != null) {
            LANG = features.userInfo.defaultLocale;
            LC_ALL = features.userInfo.defaultLocale;
          };
        }
        (mkIf (config.ordenada.globals.shell == null) {
          ## On macOS, .profile isn't sourced by default, so source it if shell isn't
          ## set so other modules work properly
          programs.zsh.enable = true;
          programs.zsh.loginShellInit = ''
            [[ -f "$HOME/.profile" ]] && source "$HOME/.profile"
          '';
        })
      ]))

      ## linux
      (ifLinux options {
        targets.genericLinux.enable = true;
        ## Starting the chosen wm on the desired tty if enabled
        environment.loginShellInit = mkIf (cfg.autoStartWmOnTty != null) ''
          [[ $(tty) == ${cfg.autoStartWmOnTty} ]] && exec ${config.ordenada.globals.wm}
        '';
        i18n.defaultLocale = mkIf (features.userInfo.defaultLocale != null) features.userInfo.defaultLocale;
      })
    ]))
    {
      home-manager = mkHomeConfig config "home" (user: {
        programs.home-manager.enable = true;
        home.stateVersion = "24.05";

        ## If the user isn't using any of the shell modules, add the session-vars to .profile
        ## ourselves so other modules work properly
        home.file.".profile".text = mkIf (config.ordenada.globals.shell == null) ''
          . "${config.home-manager.users.${user.name}.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
        '';
      });

      users = mkMerge [
        ## linux
        (ifLinux options (
          mkHomeConfig config "home" (user: {
            isNormalUser = true;
            extraGroups = [ "wheel" ] ++ user.features.home.extraGroups;
          })
        ))

        ## darwin
        (ifDarwin options (
          mkHomeConfig config "home" (user: {
            home = features.userInfo.homeDirectory;
          })
        ))
      ];
    }
  ];
}
