{
  description = "Quickshell - QtQuick based Wayland Shell Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Quickshell must be pulled in as a flake input as it is not in nixpkgs
    quickshell.url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    quickshell,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          # Apply quickshell overlay if provided, or append it to the packages
          overlays = [quickshell.overlays.default];
        };
      in {
        # Utilizing qt6.mkDerivation ensures proper QML and Qt plugin paths
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "clavis-shell";
          version = "git-snapshot";

          # cleanSource prevents .git and build/ directories from invalidating the cache
          src = pkgs.lib.cleanSource ./.;

          nativeBuildInputs = [
            pkgs.cmake
            pkgs.pkg-config
            pkgs.python3
            pkgs.qt6.wrapQtAppsHook
            pkgs.qt6.qttools
            pkgs.wayland-scanner
          ];
          buildInputs = [
            pkgs.qt6.qtbase
            pkgs.qt6.qtdeclarative
            pkgs.qt6.qtwayland
            pkgs.qt6.qtsvg
            pkgs.qt6.qt5compat
            pkgs.qt6Packages.qtkeychain
            pkgs.wayland
            pkgs.wayland-protocols
            pkgs.pam
            pkgs.networkmanager
            pkgs.pipewire
            pkgs.fftw
            pkgs.libcava
            pkgs.quickshell
          ];

          # RPATH stripping is removed; Nix's fixupPhase handles RPATH patching safely.
          cmakeFlags = [
            "-DCMAKE_BUILD_TYPE=Release"
            "-DCMAKE_SKIP_BUILD_RPATH=ON"
          ];
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [self.packages.${system}.default];
          packages = [
            pkgs.clang-tools
            pkgs.nixpkgs-fmt
          ];
        };
      }
    );
}
