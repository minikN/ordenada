{
  config,
  lib,
  pkgs,
  ...
}:

with pkgs.lib.ordenada;

let
  json5-ts-mode = pkgs.emacsPackages.trivialBuild {
    pname = "json5-ts-mode";
    version = "0.0.0";

    src = builtins.fetchGit {
      url = "https://github.com/dochang/json5-ts-mode.git";
      rev = "8ef36adff943bed504148e54cfff505b92674c10";
    };

    elispFiles = [ "json5-ts-mode.el" ];

    meta = {
      description = "A Emacs tree-sitter major mode for editing JSON5 files";
      homepage = "https://github.com/dochang/json5-ts-mode";
      license = pkgs.lib.licenses.gpl3Plus;
    };
  };
in
{
  options.ordenada.features.json5 = {
    enable = lib.mkEnableOption "the JSON5 feature";
  };

  config = {
    home-manager = mkHomeConfig config "json5" (user: {
      home.packages = with pkgs; [
        formatjson5
      ];
      programs.emacs = mkElispConfig {
        name = "ordenada-json5";
        config = # elisp
          ''
            (require 'json5-ts-mode)
            (add-to-list 'auto-mode-alist
                         '("\\.json5\\'" . json5-ts-mode))
          '';
        elispPackages = with pkgs.emacsPackages; [
          json5-ts-mode
          (treesit-grammars.with-grammars (
            grammars: with grammars; [
              tree-sitter-json5
            ]
          ))
        ];
      };
    });
  };
}
