{poetry2nix, pkgs, lib, projectDir}:
let
    # NOTE: This means we need to add fenix as an overlay to packages.
    fenix = pkgs.fenix;
    poetryOverrides = final: prev: {
        # poetry2nix doesn't run apsw's setuptools correctly, so it tries to fetch
        # sqlite from the internet. So I'm using apsw from nixpkgs and overriding the src.
        apsw = pkgs.python310Packages.apsw.overrideAttrs (_: {
            src = prev.apsw.src;
        });
        # types-peewee uses wheel
        types-peewee = prev.types-peewee.override {
            preferWheel = true;
        };
        # Polars is written in rust and is built using maturin
        polars = 
        let
            sha256 = "sha256-MW6ZeFLZ9aYzeee8OKKbXjpLauOW5yVJ1fvFU/6N9vw=";
            # Use nightly rust, because polars uses nightly rust features
            toolchain = fenix.toolchainOf {
                channel = "nightly";
                date = "2023-07-27";
                sha256 = "sha256-1bUA3mqH455LncZMMH1oEBFLWu5TOluJeDZ8iwAsBGs=";
            };
            rustPlatform = pkgs.makeRustPlatform {
                cargo = toolchain.cargo;
                rustc = toolchain.rustc;
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
            maturinBuildFlags = "-m ${cargoRoot}/Cargo.toml -o ./target/wheels";
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
    };
    inherit (poetry2nix) mkPoetryEnv;
in
mkPoetryEnv {
    inherit projectDir;
    overrides = poetry2nix.overrides.withDefaults poetryOverrides;
}