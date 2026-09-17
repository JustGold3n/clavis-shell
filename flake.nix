{
  description = "Quickshell - QtQuick based Wayland Shell Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "clavis-shell";
          version = "git-snapshot";

          # Points to the root of the current git repository
          src = ./.;

          # Native build inputs are executed on the build machine
          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
            python3
            qt6.wrapQtAppsHook
            qt6.qttools
            wayland-scanner
          ];

          # Build inputs are linked against the final binary
          buildInputs = with pkgs; [
            qt6.qtbase
            qt6.qtdeclarative
            qt6.qtwayland
            qt6.qtsvg
            qt6.qt5compat
            qt6Packages.qtkeychain
            wayland
            wayland-protocols
            pam
            networkmanager
            pipewire
            fftw
            libcava
            quickshell
          ];

          # Standard CMake release flag for optimized, stripped binaries
          cmakeFlags = [
            "-DCMAKE_BUILD_TYPE=Release"
            "-DCMAKE_SKIP_BUILD_RPATH=ON"
          ];
        };

        # Provides a development environment with all dependencies
        devShells.default = pkgs.mkShell {
          inputsFrom = [self.packages.${system}.default];
          packages = with pkgs; [
            clang-tools
            nixpkgs-fmt
          ];
        };
      }
    );
}
