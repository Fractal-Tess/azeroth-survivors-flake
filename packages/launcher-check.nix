{
  runCommand,
  bash,
  coreutils,
  util-linux,
}:
runCommand "azeroth-survivors-launcher-check"
  {
    nativeBuildInputs = [
      bash
      coreutils
      util-linux
    ];
  }
  ''
      mkdir -p fixture tools
      printf original > fixture/AzerothSurvivors.exe
      printf asset > fixture/data.bin
      cat > tools/steam-run <<'SH'
    #!${bash}/bin/bash
    set -euo pipefail
    printf '%s\n' "$@" > "$TEST_RESULT"
    printf '%s\n' "$STEAM_COMPAT_DATA_PATH" > "$TEST_PREFIX"
    test "$WGPU_BACKEND" = vulkan
    SH
      chmod +x tools/steam-run
      export PATH="$PWD/tools:$PATH"
      export TEST_RESULT="$PWD/result-args"
      export TEST_PREFIX="$PWD/result-prefix"
      substitute ${./launcher.sh} launcher.sh \
        --replace-fail '@PAYLOAD@' "$PWD/fixture" \
        --replace-fail '@PROTON@' '/bundled/proton'
      export HOME="$PWD/fresh home"
      export XDG_DATA_HOME="$HOME/data"
      bash -euo pipefail launcher.sh 'argument with spaces'
      game="$XDG_DATA_HOME/azeroth-survivors/game"
      test -w "$game/data.bin"
      grep -Fx '/bundled/proton' "$TEST_RESULT"
      grep -Fx 'argument with spaces' "$TEST_RESULT"
      printf updated > "$game/AzerothSurvivors.exe"
      bash -euo pipefail launcher.sh
      test "$(cat "$game/AzerothSurvivors.exe")" = updated
      export HOME="$PWD/legacy home"
      legacy="$HOME/Games/azeroth-survivors"
      mkdir -p "$legacy/windows/AzerothSurvivors" "$legacy/proton-prefix"
      printf legacy > "$legacy/windows/AzerothSurvivors/AzerothSurvivors.exe"
      printf save > "$legacy/proton-prefix/save"
      runtime="$HOME/.local/share/Steam/steamapps/common/Proton Hotfix/proton"
      mkdir -p "$(dirname "$runtime")"
      touch "$runtime"
      bash -euo pipefail launcher.sh
      grep -Fx "$runtime" "$TEST_RESULT"
      grep -Fx "$legacy/proton-prefix" "$TEST_PREFIX"
      test "$(cat "$legacy/proton-prefix/save")" = save
      test "$(cat "$legacy/windows/AzerothSurvivors/AzerothSurvivors.exe")" = legacy
      touch "$out"
  ''
