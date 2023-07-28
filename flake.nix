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
    outputs = inputs@{flake-parts, ...}:
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
                devshells.default = {
                    packages = [
                        pkgs.ruff
                        (mkPoetryEnv {
                            projectDir = ./.;
                        })
                    ];
                };
            };
        };
}
