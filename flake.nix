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
        fenix = {
            url = "github:nix-community/fenix";
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
                        pkgs.poetry
                        (mkPoetryEnv {
                            projectDir = ./.;
                            overrides = poetry2nix.overrides.withDefaults (final: prev: {
                                # poetry2nix doesn't run apsw's setuptools correctly, so it tries to fetch
                                # sqlite from the internet. So I'm using apsw from nixpkgs and overriding the src.
                                apsw = pkgs.python310Packages.apsw.overrideAttrs (_: {
                                    src = prev.apsw.src;
                                });
                                # types-peewee uses wheel
                                types-peewee = prev.types-peewee.override {
                                    preferWheel = true;
                                };
                                polars = 
                                let
                                    sha256 = "sha256-MW6ZeFLZ9aYzeee8OKKbXjpLauOW5yVJ1fvFU/6N9vw=";
                                    # Use nightly rust, because polars uses nightly rust features
                                    toolchain = inputs'.fenix.packages.minimal.toolchain;
                                    rustPlatform = pkgs.makeRustPlatform {
                                        cargo = toolchain;
                                        rustc = toolchain;
                                    };
                                in
                                prev.polars.overridePythonAttrs (old: rec {
                                    src = pkgs.fetchFromGitHub {
                                        owner = "pola-rs";
                                        repo = "polars";
                                        rev = "py-${old.version}";
                                        inherit sha256;
                                    };
                                    cargoDeps = rustPlatform.importCargoLock {
                                        lockFile = "${src.out}/py-polars/Cargo.lock";
                                        outputHashes = {
                                            "arrow2-0.17.3" = "sha256-So9U+gvYUqSaVHrSOVbXVDXXTlkvMpXiTp61OSLQeaM";
                                            "jsonpath_lib-0.3.0" = "sha256-NKszYpDGG8VxfZSMbsTlzcMGFHBOUeFojNw4P2wM3qk=";
                                            "simd-json-0.10.0" = "sha256-0q/GhL7PG5SLgL0EETPqe8kn6dcaqtyL+kLU9LL+iQs=";
                                        };
                                    };
                                    cargoRoot = "py-polars";
                                    buildAndTestSubdir = "py-polars";
                                    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                                        rustPlatform.cargoSetupHook
                                        rustPlatform.maturinBuildHook
                                    ];
                                    buildInputs = with pkgs; (old.buildInputs or [ ]) 
                                        ++ lib.optionals stdenv.isDarwin [ 
                                            libiconv
                                            darwin.apple_sdk.frameworks.Security
                                        ];
                                });
                            });
                        })
                    ];
                };
            };
        };
}
