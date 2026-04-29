{
  lib,
  mkFeature,
  ordenada-lib,
  ...
}:

mkFeature {
  name = "javascript";
  options =
    { pkgs, ... }:
    {
      node = lib.mkPackageOption pkgs "nodejs" { };
      bun = lib.mkPackageOption pkgs "bun" { };
    };
  homeManager =
    { config, pkgs, ... }:
    {
      home.packages =
        with config.ordenada.features.javascript;
        [
          node
          bun
        ]
        ++ (with pkgs; [
          (yarn.override { nodejs = null; })
          nodePackages.prettier
        ]);
      programs.emacs = ordenada-lib.mkElispConfig pkgs {
        name = "ordenada-javascript";
        config = # elisp
''
            (defgroup ordenada-javascript nil
              "General JavaScript/TypeScript programming utilities."
              :group 'ordenada)
            (defvar ordenada-javascript-mode-map (make-sparse-keymap))

            (setq major-mode-remap-alist
                  '((javascript-mode . js-ts-mode)
                    (js-mode         . js-ts-mode)
                    (js2-mode        . js-ts-mode)
                    (typescript-mode . typescript-ts-mode)))

            (add-to-list 'auto-mode-alist '("\\.jsx\\'" . tsx-ts-mode))
            (add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
            (add-to-list 'auto-mode-alist '("\\.ts\\'"  . typescript-ts-mode))
            (add-to-list 'auto-mode-alist '("\\.js\\'"  . js-ts-mode))

            (define-minor-mode ordenada-javascript-mode
              "Set up convenient tweaks for JavaScript/TypeScript development."
              :group 'ordenada-javascript :keymap ordenada-javascript-mode-map
              (when ordenada-javascript-mode
                (setopt tab-width 2)
                (eglot-ensure)
                ${lib.optionalString config.ordenada.features.emacs.corfu.enable ''
                  (corfu-mode 1)
                ''}
                ))

            (mapcar (lambda (hook)
                      (add-hook (intern (concat (symbol-name hook) "-hook")) 'ordenada-javascript-mode))
                    '(js-ts-mode typescript-ts-mode tsx-ts-mode))

            (with-eval-after-load 'eglot
              (add-to-list
               'eglot-server-programs
               '(((jsx-ts-mode :language-id "javascriptreact")
                  (js-ts-mode :language-id "javascript")
                  (tsx-ts-mode :language-id "typescriptreact")
                  (typescript-ts-mode :language-id "typescript")) .
                  ("${pkgs.typescript-language-server}/bin/typescript-language-server" "--stdio"))))

            (with-eval-after-load 'js
              (setopt js-indent-level 2)
              (setopt js-chain-indent t))

            (add-to-list 'major-mode-remap-alist '(css-mode . css-ts-mode))
              (with-eval-after-load 'css-mode
              (setopt css-indent-offset 2))
          '';
        elispPackages = with pkgs.emacsPackages; [
          (treesit-grammars.with-grammars (
            grammars: with grammars; [
              tree-sitter-javascript
              tree-sitter-tsx
              tree-sitter-typescript
            ]
          ))
        ];
      };
    };
}
