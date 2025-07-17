{ config, lib, pkgs, ... }:

with pkgs.lib.ordenada;

let
  inherit (lib) mkEnableOption mkOption types;
  features = config.ordenada.features;
  cfg = features.rofi;
  rofiPkg =
    if config.ordenada.globals.wayland then pkgs.rofi-wayland else pkgs.rofi;
in {
  options = {
    ordenada.features.rofi = {
      enable = mkEnableOption "the rofi feature";
      package = mkOption {
        type = types.package;
        default = rofiPkg;
        description = "The rofi package to use.";
      };
      showActions = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to show actions.";
      };
      showIcons = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to show icons.";
      };
      enableLauncher = mkOption {
        type = types.bool;
        description = "Whether to enable this feature as the global launcher.";
        default = true;
      };
      enablePinentry = mkOption {
        type = types.bool;
        description = "Whether to enable this feature as the global pinentry.";
        default = true;
      };
      enablePasswordManager = mkOption {
        type = types.bool;
        description =
          "Whether to enable this feature as the global password manager.";
        default = true;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    ## TODO: Use a `setGlobal` function here to check for `ordenada.globals.launcher === null`
    ##       and print a warning if so
    ordenada.globals.launcher =
      mkIf cfg.enableLauncher "${cfg.package}/bin/rofi -show drun";

    ordenada.globals.passwordManager = mkIf cfg.enablePasswordManager "${
        if config.ordenada.globals.wayland then
          pkgs.rofi-pass-wayland
        else
          pkgs.rofi-pass
      }/bin/rofi-pass";

    home-manager = mkHomeConfig config "rofi" (user:
      with config.home-manager.users.${user.name}.programs.rofi; {
        programs.rofi = {
          enable = true;
          package = user.features.rofi.package;
          extraConfig = {
            modi = "run,ssh,drun";
            drun-show-actions = cfg.showActions;
            show-icons = cfg.showIcons;

            font = with user.features.fontutils.fonts.monospace;
              "${name} ${toString size}";

            kb-element-next = "Alt+n";
            kb-element-prev = "Alt+p";

            kb-page-next = "Super+n";
            kb-page-prev = "Super+p";

            kb-row-select = "Tab,Control+i";
            kb-secondary-paste = "Control+y";
            kb-remove-word-forward = "Alt+d";
            kb-remove-word-back = "Control+w,Control+BackSpace";
            kb-clear-line = "Control+slash";
          };

          theme = let
            inherit (config.home-manager.users.${user.name}.lib.formats.rasi)
              mkLiteral;
          in {
            "*" = with user.features.theme.scheme.withHashtag; {
              border = 0;
              margin = 0;
              padding = 0;
              spacing = 0;

              bg0 = mkLiteral base01;
              bg1 = mkLiteral base02;

              fg0 = mkLiteral base05;
              fg1 = mkLiteral base06;

              urgent-color = mkLiteral base12;

              background-color = mkLiteral "transparent";
              text-color = mkLiteral "@fg0";
            };
            window = {
              location = mkLiteral "center";
              width = 600;
              height = 400;
              background-color = mkLiteral "@bg0";
              border = mkLiteral "2px";
              border-color = mkLiteral "@bg1";
              padding = mkLiteral "4px";
            };
            inputbar = {
              spacing = mkLiteral "8px";
              padding = mkLiteral "8px";
              background-color = mkLiteral "@bg1";
            };
            "prompt, entry, element-icon, element-text" = {
              vertical-align = mkLiteral "0.5";
            };
            prompt = { text-color = mkLiteral "@text-color"; };
            textbox = {
              padding = mkLiteral "8px";
              background-color = mkLiteral "@bg1";
            };
            listview = {
              padding = mkLiteral "4px 0";
              lines = 8;
              columns = 1;
              fixed-height = true;
            };
            element = {
              padding = mkLiteral "8px";
              spacing = mkLiteral "8px";
            };
            "element normal normal" = { text-color = mkLiteral "@fg0"; };
            "element normal urgent" = {
              text-color = mkLiteral "@urgent-color";
            };
            "element normal active" = { text-color = mkLiteral "@fg0"; };
            "element alternate active" = { text-color = mkLiteral "@fg0"; };
            "element selected" = { text-color = mkLiteral "@fg0"; };
            "element selected normal, element selected active" = {
              background-color = mkLiteral "@bg1";
            };
            "element selected urgent" = {
              background-color = mkLiteral "@urgent-color";
            };
            "element-icon" = { size = mkLiteral "0.8em"; };
            "element-text" = { text-color = mkLiteral "inherit"; };
          };
        };

        ## Setting rofi as pinentry
        services.gpg-agent.pinentry.package =
          lib.mkIf cfg.enablePinentry (lib.mkForce pkgs.pinentry-rofi);

        xdg.configFile."rofi-pass/config".text = ''
          _rofi () {
            ${config.ordenada.globals.launcher} -i -no-auto-select "$@"
          }
          clibpoard_backend=${
            if config.ordenada.globals.wayland then
              "wl-clipboard"
            else
              "xclip"
          }
          backend=${
            if config.ordenada.globals.wayland then
              "wtype"
            else
              "xdotool"
          }

          copy_pass="Alt+y"
          insert_pass="Alt+Y"
        '';
      });
  };
}
