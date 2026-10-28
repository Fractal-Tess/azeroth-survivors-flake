{
  lib,
  stdenvNoCC,
  fetchurl,
  unrar-free,
  writeShellApplication,
  util-linux,
  steam-run,
  proton-ge-bin,
  makeDesktopItem,
  symlinkJoin,
}:
let
  payload = stdenvNoCC.mkDerivation {
    pname = "azeroth-survivors-windows";
    version = "0.102.3";
    src = fetchurl {
      url = "https://wow.aethus.pl/download/AzerothSurvivorsWindowsNew.rar";
      hash = "sha256-bPEQjbTovX9V4hTiTpdqbySrZXo+7YbBZ0P/dua4VnE=";
    };
    nativeBuildInputs = [ unrar-free ];
    dontUnpack = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      unrar-free --extract "$src" "$out/"
      test -f "$out/AzerothSurvivors/AzerothSurvivors.exe"
      runHook postInstall
    '';
  };
  launcher = writeShellApplication {
    name = "azeroth-survivors";
    runtimeInputs = [
      steam-run
      util-linux
    ];
    text =
      builtins.replaceStrings
        [ "@PAYLOAD@" "@PROTON@" ]
        [ "${payload}/AzerothSurvivors" "${proton-ge-bin.steamcompattool}/proton" ]
        (builtins.readFile ./launcher.sh);
  };
  desktop = makeDesktopItem {
    name = "azeroth-survivors-native";
    desktopName = "Azeroth Survivors (Proton)";
    comment = "Official Windows game through Proton with Vulkan";
    exec = "${launcher}/bin/azeroth-survivors";
    icon = "applications-games";
    categories = [ "Game" ];
    terminal = false;
  };
in
symlinkJoin {
  name = "azeroth-survivors-${payload.version}";
  paths = [
    launcher
    desktop
  ];
  passthru = { inherit payload; };
  meta = {
    description = "Aethus's Azeroth Survivors, with a writable game installation and Proton";
    homepage = "https://wow.aethus.pl/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "azeroth-survivors";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
