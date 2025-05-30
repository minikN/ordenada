{ pkgs, lib, ... }:

let
  eval = lib.evalModules {
    specialArgs = {
      inherit pkgs;
    };
    modules = [
      { _module.check = false; }
      ./modules
    ];
  };
  cleanEval = lib.filterAttrsRecursive (n: v: n != "_module") eval;
  ordenadaPath = toString ./.;
  repoDeclaration = subpath: {
    url = "https://github.com/migalmoreno/ordenada/blob/master/${subpath}";
    name = "<ordenada/${subpath}>";
  };
  optionsDoc = pkgs.nixosOptionsDoc {
    inherit (cleanEval) options;
    transformOptions =
      opt:
      opt
      // {
        declarations = map (
          decl:
          if lib.hasPrefix ordenadaPath (toString decl) then
            repoDeclaration (lib.removePrefix "/" (lib.removePrefix ordenadaPath (toString decl)))
          else
            decl
        ) opt.declarations;
      };
  };
in
pkgs.runCommand "ordenada-docs"
  {
    buildInputs = [
      pkgs.pandoc
      pkgs.emacs
    ];
  }
  ''
    tmpdir=$(mktemp -d)
    mkdir -p $out
    sed '$ d' ${./README} > $tmpdir/README

    cat ${optionsDoc.optionsCommonMark} > $tmpdir/options.md
    cat $tmpdir/options.md > $out/options.md

    emacs --batch --eval \
      "(progn (require 'ox) (require 'ox-md) \
       (find-file \"$tmpdir/README\") \
       (org-export-to-file 'md \"$tmpdir/readme.md\") (bury-buffer))"
    cat $tmpdir/readme.md $tmpdir/options.md > $out/index.md

    pandoc -f markdown -o $tmpdir/options.org $tmpdir/options.md
    cat $tmpdir/README $tmpdir/options.org > $out/index.org
    cat $tmpdir/README > $out/readme.org

    pandoc -f markdown+smart -o $out/index.html $out/index.md
  ''
