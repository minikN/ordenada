{ lib, mkFeature, ordenada-lib, ... }:

mkFeature {
  name = "direnv";
  homeManager =
    { config, pkgs, ... }:
    {
      home.packages = with pkgs; [ direnv ];
      programs.emacs = ordenada-lib.mkElispConfig pkgs {
        name = "ordenada-direnv";
        config = ''
          (eval-when-compile (require 'envrc))
          (add-hook 'after-init-hook #'envrc-global-mode)
          (with-eval-after-load 'envrc
            (keymap-set envrc-mode-map "C-c E" #'envrc-command-map))
        '';
        elispPackages = with pkgs.emacsPackages; [ envrc ];
      };
      programs.bash.bashrcExtra = let
        enabled = config.ordenada.features.bash.enable == true;
      in lib.mkIf(enabled) ''
        eval "$(direnv hook bash)"
      '';
    };
}
