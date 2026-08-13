# From https://github.com/the-nix-way/dev-templates/blob/main/c-cpp/flake.nix
{
	description = "A Nix-flake-based C/C++ development environment";

	inputs = {
		nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0"; # stable Nixpkgs
		devkitNix = {
			url = "github:bandithedoge/devkitNix";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = {
		self,
		devkitNix,
		...
	} @ inputs: let
		supportedSystems = [
			"x86_64-linux"
		];
		forEachSupportedSystem = f:
			inputs.nixpkgs.lib.genAttrs supportedSystems (
				system:
					f {
						inherit system;
						pkgs =
							import inputs.nixpkgs {
								inherit system;
								overlays = [devkitNix.overlays.default];
							};
					}
			);
	in {
		devShells =
			forEachSupportedSystem (
				{
					pkgs,
					system,
				}: let
					llvmPkgs = pkgs.llvmPackages_22;
				in {
					default =
						pkgs.mkShell.override
						{
							stdenv = llvmPkgs.stdenv;
						}
						{
							packages = with pkgs;
								[
									llvmPkgs.clang-tools
									cmake
									doxygen
									ninja
									python3
									fmt
									argparse
									verilator
									ccache
									gtest
									nlohmann_json
									tl-expected
									surfer
									SDL2
									libx11
									nanoboyadvance
									pkgs.devkitNix.devkitARM
								]
								++ lib.optionals (!llvmPkgs.stdenv.hostPlatform.isDarwin) [gdb];

							shellHook = ''
								export DEVKITPRO=${pkgs.devkitNix.devkitARM}/opt/devkitpro
								export DEVKITARM=$DEVKITPRO/devkitARM
							'';
						};
				}
			);

		formatter = forEachSupportedSystem ({pkgs, ...}: pkgs.nixfmt);
	};
}
