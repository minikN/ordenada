{
  lib,
  mkFeature,
  ordenada-lib,
  ...
}:

mkFeature {
  name = [
    "emacs"
    "corfu"
  ];
  options = {
    autoShow = lib.mkOption {
      type = lib.types.bool;
      description = "Whether the corfu popup should appear automatically while typing.";
      default = false;
    };
  };
  homeManager =
    { config, pkgs, ... }:
    {
      programs.emacs = ordenada-lib.mkElispConfig pkgs {
        name = "ordenada-corfu";
        config = with config.ordenada.features.emacs.corfu; ''
          (unless (display-graphic-p)
            (corfu-terminal-mode +1))
          (setopt tab-always-indent t)
          (with-eval-after-load 'corfu
            (setopt corfu-auto ${if autoShow then "t" else "nil"})
            (setopt corfu-cycle t)
            (setopt corfu-preview-current nil)

            ;; Enable in minibuffer
            (defun ordenada-corfu-enable-in-minibuffer ()
              "Enable Corfu in the minibuffer if `completion-at-point' is bound."
              (when (where-is-internal 'completion-at-point
                                       (list (current-local-map)))
                (corfu-mode 1)))
            (add-hook 'minibuffer-setup-hook #'ordenada-corfu-enable-in-minibuffer)

            ;; Move to minibuffer
            (defun ordenada-corfu-move-to-minibuffer ()
              (interactive)
              (pcase completion-in-region--data
                (`(,beg ,end ,table ,pred ,extras)
                 (let ((completion-extra-properties extras)
                       completion-cycle-threshold completion-cycling)
                   (consult-completion-in-region beg end table pred)))))
            (keymap-set corfu-map "M-m" #'ordenada-corfu-move-to-minibuffer)
            (add-to-list 'corfu-continue-commands #'ordenada-corfu-move-to-minibuffer)
            (keymap-set corfu-map "M-m" #'ordenada-corfu-move-to-minibuffer))
        '';
        elispPackages = with pkgs.emacsPackages; [
          cape
          corfu
          corfu-terminal
        ];
      };
    };
}
