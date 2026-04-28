{ lib, mkFeature, ordenada-lib, ... }:

let
  inherit (lib) types mkOption;
in
mkFeature {
  name = [
    "emacs"
    "flymake"
  ];
  options = {
    showIndicators = mkOption {
      type = types.bool;
      description = "Whether to show the indicators in the left fringe.";
      default = false;
    };
  };
  homeManager =
    { config, pkgs, ... }:
    {
      programs.emacs = ordenada-lib.mkElispConfig pkgs {
        name = "ordenada-flymake";
        config = with config.ordenada.features.emacs.flymake; # elisp
          ''
            (with-eval-after-load 'flymake
              (setopt flymake-indicator-type ${if showIndicators then "'fringes" else "nil"})
              (let ((map flymake-mode-map))
                (keymap-set map "M-n" #'flymake-goto-next-error)
                (keymap-set map "M-p" #'flymake-goto-prev-error)))
          '';
      };
    };
}
