{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  package = self.packages.${pkgs.stdenv.hostPlatform.system}.azeroth-survivors;
  cfg = config.programs.azeroth-survivors;
in
{
  options.programs.azeroth-survivors = import ./options.nix { inherit lib package; };
  config = lib.mkIf cfg.enable { home.packages = [ cfg.package ]; };
}
