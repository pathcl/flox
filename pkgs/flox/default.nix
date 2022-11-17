{
  system,
  # self is a flake if this package is built localy, but if it's called as a proto, it's just the
  # source
  self,
  lib,
  rustPlatform,
  hostPlatform,
  openssl,
  pkg-config,
  darwin,
  flox-bash ? self.inputs.floxpkgs-internal.packages.${system}.flox-bash,
  nix,
  pandoc,
  cacert,
  glibcLocales,
  installShellFiles,
}: let
  cargoToml = lib.importTOML (self + "/crates/flox/Cargo.toml");

  envs =
    {
      NIX_BIN = "${nix}/bin/nix";
      FLOX_SH = "${flox-bash}/libexec/flox/flox";
      NIXPKGS_CACERT_BUNDLE_CRT = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    }
    // lib.optionalAttrs hostPlatform.isDarwin {
      NIX_COREFOUNDATION_RPATH = "${darwin.CF}/Library/Frameworks";
      PATH_LOCALE = "${darwin.locale}/share/locale";
    }
    // lib.optionalAttrs hostPlatform.isLinux {
      LOCALE_ARCHIVE = "${glibcLocales}/lib/locale/locale-archive";
    };
in
  rustPlatform.buildRustPackage ({
      pname = cargoToml.package.name;
      version = "${cargoToml.package.version}-r${toString self.revCount or "dirty"}";
      src = self;

      cargoLock = {
        lockFile = self + "/Cargo.lock";
      };

      buildAndTestSubdir = "crates/flox";

      doCheck = false;

      postInstall = ''
        # TODO move .md file to this repo
        # pandoc --standalone -t man ${self}/flox.1.md -o flox.1
        installManPage ${flox-bash}/share/man/man1/flox.1.gz
      '';

      buildInputs =
        [
          openssl.dev
        ]
        ++ lib.optional hostPlatform.isDarwin [
          darwin.apple_sdk.frameworks.Security
        ];

      nativeBuildInputs = [
        pkg-config # for openssl
        pandoc
        installShellFiles
      ];

      passthru.envs = envs;
    }
    // envs)