{
  config,
  lib,
  pkgs,
  ...
}:

with pkgs.lib.ordenada;

let
  json-simple-flymake = pkgs.emacsPackages.trivialBuild {
    pname = "json-simple-flymake";
    version = "unstable-2023-09-03";

    src = builtins.fetchGit {
      url = "https://github.com/mokrates/json-simple-flymake.git";
      rev = "f3dacf070d1e04d5805323b0a95d58c5b9b7f607";
    };

    elispFiles = [ "json-simple-flymake.el" ];

    meta = {
      description = "Simple JSON syntax checker using Flymake for Emacs";
      homepage = "https://github.com/mokrates/json-simple-flymake";
      license = pkgs.lib.licenses.gpl3Plus;
    };
  };
in
{
  options.ordenada.features.json = {
    enable = lib.mkEnableOption "the JSON feature";
  };

  config = {
    home-manager = mkHomeConfig config "json" (user: {
      home.packages = with pkgs; [
        jq
      ];
      programs.emacs = mkElispConfig {
        name = "ordenada-json";
        config = # elisp
          ''
            (require 'treesit)
            (when (and (treesit-available-p)
                       (treesit-language-available-p 'json))
            (progn
              (add-to-list 'major-mode-remap-alist '(json-mode . json-ts-mode))
                ;; Additionally remapping js-json-mode if `feature-javascript' is
                ;; enabled
                ${mkIf (hasFeature "javascript" user) ''
                  (add-to-list 'major-mode-remap-alist
                               '(js-json-mode . json-ts-mode))
                ''}
            ))
            ;; Activating json flymake checker upon enabling json-ts-mode
            (add-hook 'json-ts-mode-hook
              (lambda ()
                ;; load json flymake checker
                (load-library "json-simple-flymake")
                (json-simple-setup-flymake-backend)

                ;; Add flymake diagnostics to mode bar
                (add-to-list 'mode-line-misc-info
                `(flymake-mode
                   (" " flymake-mode-line-counters " ")))
                   ;; Enable flymake
                   (flymake-mode t)))
          '';
        elispPackages = with pkgs.emacsPackages; [
          json-mode
          json-simple-flymake
          (treesit-grammars.with-grammars (
            grammars: with grammars; [
              tree-sitter-json
            ]
          ))
        ];
      };
    });
  };
}
