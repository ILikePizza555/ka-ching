{
    description = "Description of flake";
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs";
        flake-parts.url = "github:hercules-ci/flake-parts";
        devshell.url = "github:numtide/devshell";
        poetry2nix = {
            url = "github:nix-community/poetry2nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };
  };
    outputs = inputs@{nixpkgs, flake-parts, ...}:
        flake-parts.lib.mkFlake { inherit inputs; } {
            imports = [
                inputs.devshell.flakeModule
            ];
            systems = [
                "x86_64-linux"
                "aarch64-darwin"
            ];
            perSystem = { system, pkgs, inputs', ... }:
            let
                poetry2nix = inputs'.poetry2nix.legacyPackages;
                inherit (poetry2nix) mkPoetryEnv;
            in
            {
                # Defining nixpkgs overlays
                _module.args.pkgs = import nixpkgs {
                    inherit system;
                    overlays = [
                        # Overlay for ruff to use the latest version
                        (final: prev: {
                            ruff = prev.ruff.overrideAttrs (old: rec {
                                version = "0.0.280";
                                src = prev.fetchFromGitHub {
                                    owner = "astral-sh";
                                    repo = "ruff";
                                    rev = "v${version}";
                                    hash = "sha256-Pp/yurRPUHqrCD3V93z5EGMYf4IyLFQOL9d2sNe3TKs=";
                                };
                            });
                        })
                    ];
                };
                devshells.default = {
                    packages = [
                        pkgs.sqlite
                        pkgs.ruff
                        (mkPoetryEnv {
                            projectDir = ./.;
                        })
                    ];
                };
            };
        };
}
