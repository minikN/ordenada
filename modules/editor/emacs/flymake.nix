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
              (add-to-list 'mode-line-misc-info `(flymake-mode (" " flymake-mode-line-counters " ")))
              (setopt flymake-mode-line-lighter "")

              ;; Removing "!" before errors
              (defun ordenada--flymake-no-before-string (diag &rest _)
                (when-let* ((ov (flymake--diag-overlay diag)))
                  (overlay-put ov 'before-string nil)))
              (advice-add 'flymake--highlight-line :after #'ordenada--flymake-no-before-string)

              ${lib.optionalString (showIndicators == false) ''
                (setopt flymake-fringe-indicator-position nil)
                (setopt flymake-margin-indicator-position nil)
              ''}
              (let ((map flymake-mode-map))
                (keymap-set map "M-n" #'flymake-goto-next-error)
                (keymap-set map "M-p" #'flymake-goto-prev-error)))
          '';
      };
    };
}
