{
  description = "The official Azeroth Survivors Windows game packaged for Linux with Proton";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      game = pkgs.callPackage ./packages/azeroth-survivors.nix { };
    in
    {
      packages.${system} = {
        azeroth-survivors = game;
        default = game;
      };
      apps.${system}.default = {
        type = "app";
        program = "${game}/bin/azeroth-survivors";
        meta.description = "Play Azeroth Survivors through Proton";
      };
      checks.${system} = {
        package = game;
        launcher = pkgs.callPackage ./packages/launcher-check.nix { };
      };
      formatter.${system} = pkgs.nixfmt;
      overlays.default = final: _prev: {
        azeroth-survivors = final.callPackage ./packages/azeroth-survivors.nix { };
      };
      nixosModules.default = import ./modules/nixos.nix { inherit self; };
      homeManagerModules.default = import ./modules/home-manager.nix { inherit self; };
    };
}
