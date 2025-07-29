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
            (setq json5-ts-mode-indent-offset 2)

            (defun ordenada-json5-format-buffer ()
              "Format the current buffer using the hardcoded 'formatjson5' executable via stdout.
            Passes --indent from `json5-ts-mode-indent-offset`. Preserves Tree-sitter node position if possible."
              (interactive)
              (unless (eq major-mode 'json5-ts-mode)
                (error "This function requires `json5-ts-mode` enabled"))
              (let* ((formatjson5-path "${pkgs.formatjson5}/bin/formatjson5")
                     (indent (or (and (boundp 'json5-ts-mode-indent-offset)
                                      json5-ts-mode-indent-offset)
                                 2)) ;; fallback default indent
                     (input-file (make-temp-file "ordenada-json5-input" nil ".json5"))
                     (output-buffer (get-buffer-create "*ordenada-json5-output*"))
                     (error-file (make-temp-file "ordenada-json5-errors"))
                     (original-node (treesit-node-at (point)))
                     (original-node-type (when original-node (treesit-node-type original-node)))
                     (original-node-text (when original-node (treesit-node-text original-node)))
                     (window-start-pos (window-start))
                     (exit-code nil))
                (unless (file-executable-p formatjson5-path)
                  (error "Executable not found or not executable: %s" formatjson5-path))
                (unwind-protect
                    (progn
                      (write-region (point-min) (point-max) input-file nil 'silent)
                      (with-current-buffer output-buffer (erase-buffer))
                      (setq exit-code
                            (apply #'call-process formatjson5-path nil
                                   (list output-buffer error-file)
                                   t ;; <-- THE FIX: Force synchronous execution to get the real exit code.
                                   `("--indent" ,(number-to-string indent) ,input-file)))
                      (if (zerop exit-code)
                          (let ((formatted (with-current-buffer output-buffer (buffer-string))))
                            (erase-buffer)
                            (insert formatted)
                            ;; Reparse tree after buffer replaced
                            (when (fboundp 'treesit-force-reparse)
                              (treesit-force-reparse))
                            ;; Try to find a matching node to restore point
                            (let ((new-node (when (and original-node-type original-node-text (fboundp 'treesit-search-subtree))
                                              (treesit-search-subtree
                                               (treesit-buffer-root-node)
                                               (lambda (node)
                                                 (and
                                                  (string= (treesit-node-type node) original-node-type)
                                                  (string= (treesit-node-text node) original-node-text)))))))
                              (if new-node
                                  (goto-char (treesit-node-start new-node))
                                ;; fallback: just restore window start and leave point at beginning
                                (goto-char (point-min))))
                            (set-window-start (selected-window) window-start-pos)
                            (message "Buffer formatted with formatjson5"))
                        (let ((errbuf (get-buffer-create "*ordenada-json5-errors*")))
                          (with-current-buffer errbuf
                            (erase-buffer)
                            (insert-file-contents error-file))
                          (display-buffer errbuf)
                          (error "formatjson5 failed with exit code %d" exit-code))))
                  (delete-file input-file)
                  (delete-file error-file))))
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
