{ lib, package }:
{
  enable = lib.mkEnableOption "Azeroth Survivors with Proton";
  package = lib.mkOption {
    type = lib.types.package;
    default = package;
    description = "Azeroth Survivors package to install.";
  };
}
