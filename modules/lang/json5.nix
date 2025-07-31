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
            (defgroup ordenada-json5 nil
              "General JSON5 programming utilities."
              :group 'ordenada)

            (defvar ordenada-json5-mode-map (make-sparse-keymap))

            (define-minor-mode ordenada-json5-mode
              "Set up convenient tweaks for JSON5 development."
              :group 'ordenada-json5 :keymap ordenada-json5-mode-map)

            (add-hook 'json5-ts-mode-hook 'ordenada-json5-mode)

            (require 'json5-ts-mode)
            (add-to-list 'auto-mode-alist
                         '("\\.json5\\'" . json5-ts-mode))
            (setq json5-ts-mode-indent-offset 2)

            (defun ordenada-json5-format-buffer (&optional skip-cursor-restore skip-mode-check buffer)
              "Format a buffer using the 'formatjson5' executable.
                        Formats BUFFER if provided, otherwise the current buffer.
                        Passes --indent from `json5-ts-mode-indent-offset`. Preserves Tree-sitter node position if possible.
                        With a prefix argument, skips cursor position restoration.
                        If SKIP-MODE-CHECK is t, it skips checking the major mode of the buffer."
              (interactive "P")
              (let ((target-buffer (or buffer (current-buffer))))
                (with-current-buffer target-buffer
                  (unless (or (eq major-mode 'json5-ts-mode) (eq skip-mode-check t))
                    (error "This function requires `json5-ts-mode` in the target buffer"))
                  (let* ((formatjson5-path "${pkgs.formatjson5}/bin/formatjson5")
                         (indent (or (and (boundp 'json5-ts-mode-indent-offset)
                                          json5-ts-mode-indent-offset)
                                     2))
                         (input-file (make-temp-file "ordenada-json5-input" nil ".json5"))
                         (output-buffer (get-buffer-create "*ordenada-json5-output*"))
                         (error-file (make-temp-file "ordenada-json5-errors"))
                         (original-node (unless skip-cursor-restore (treesit-node-at (point))))
                         (original-node-type (when original-node (treesit-node-type original-node)))
                         (original-node-text (when original-node (treesit-node-text original-node)))
                         (window (get-buffer-window target-buffer 'visible))
                         (window-start-pos (when window (window-start window)))
                         (exit-code nil))
                    (unless (file-executable-p formatjson5-path)
                      (error "Executable not found or not executable: %s" formatjson5-path))
                    (unwind-protect
                        (progn
                          ;; Setup and process call
                          (write-region (point-min) (point-max) input-file nil 'silent)
                          (with-current-buffer output-buffer (erase-buffer))
                          (setq exit-code
                                (let ((process-args `("--indent" ,(number-to-string indent) ,input-file)))
                                  (apply #'call-process
                                         formatjson5-path
                                         nil
                                         (cons (buffer-name output-buffer) error-file)
                                         t ;; Synchronous
                                         process-args)))
                          (unless (and (integerp exit-code) (zerop exit-code))
                            (let ((errbuf (get-buffer-create "*ordenada-json5-errors*")))
                              (with-current-buffer errbuf
                                (erase-buffer)
                                (insert-file-contents error-file))
                              (display-buffer errbuf))
                            (error "formatjson5 failed on buffer '%s' with exit code %S" (buffer-name target-buffer) exit-code))

                          (let ((formatted (with-current-buffer output-buffer (buffer-string))))
                            (erase-buffer)
                            (insert formatted)
                            (when (fboundp 'treesit-force-reparse)
                              (treesit-force-reparse))
                            (unless skip-cursor-restore
                              (let ((new-node (when (and original-node-type original-node-text (fboundp 'treesit-search-subtree))
                                                (treesit-search-subtree
                                                 (treesit-buffer-root-node)
                                                 (lambda (node)
                                                   (and
                                                    (string= (treesit-node-type node) original-node-type)
                                                    (string= (treesit-node-text node) original-node-text)))))))
                                (if new-node
                                    (goto-char (treesit-node-start new-node))
                                  (goto-char (point-min)))))
                            (when window-start-pos
                              (set-window-start window window-start-pos)))
                          (message "Buffer '%s' formatted with formatjson5" (buffer-name target-buffer)))

                      (delete-file input-file)
                      (delete-file error-file)
                      (when (get-buffer output-buffer)
                        (kill-buffer output-buffer)))))))

            (keymap-set ordenada-json5-mode-map "C-c f"
              '("Format buffer" . ordenada-json5-format-buffer))

            ${mkIf (hasFeature "emacs.apheleia" user) ''
              (require 'cl-lib)

              (cl-defun ordenada-json5-apheleia-formatter (&rest _args
                                                                 &key buffer scratch formatter callback remote async
                                                                 &allow-other-keys)
                "Apheleia formatter wrapper for `ordenada-json5-format-buffer`.
                                                                Performs checks and calls the formatter with specific arguments.
                                                                This function adheres to the `apheleia` interface."
                (when (eq (with-current-buffer buffer major-mode) 'json5-ts-mode)
                  (ordenada-json5-format-buffer t t scratch))

                (when callback
                  (funcall callback)))

              (with-eval-after-load 'apheleia
                (add-to-list 'apheleia-formatters '(ordenada-json5 . ordenada-json5-apheleia-formatter))
                (add-to-list 'apheleia-mode-alist '(json5-ts-mode . ordenada-json5)))
            ''}
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
