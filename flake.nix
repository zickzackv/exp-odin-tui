{
  description = "Odin Curses Project Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {inherit system;};
        });
  in {
    packages = forEachSupportedSystem ({pkgs}: {
      default = pkgs.odin;
      ols = pkgs.ols;
    });

    devShells = forEachSupportedSystem ({pkgs}: let
      system = pkgs.stdenv.system;
      olsJson = pkgs.writers.writeJSON "ols.json" {
        "$schema" = "https://raw.githubusercontent.com/DanielGavin/ols/master/misc/ols.schema.json";
        "enable_document_symbols" = true;
        "enable_fmt" = true;
        "enable_hover" = true;
        "enable_semantic_tokens" = false;
        "enable_snippets" = true;
        "verbose" = true;
      };
      odinfmtJson = pkgs.writers.writeJSON "odinfmt.json" {
        "$schema" = "https://raw.githubusercontent.com/DanielGavin/ols/master/misc/odinfmt.schema.json";
        "character_width" = 120;
        "tabs" = false;
        "tabs_width" = 8;
      };
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = [
          self.packages."${system}".default
          self.packages."${system}".ols
        ];

        shellHook = ''
          ln -sf ${olsJson} ols.json
          ln -sf ${odinfmtJson} odinfmt.json
        '';
      };
    });
  };
}
