# Reuse the earlier manual installation, including its updates and Proton saves.
legacy="$HOME/Games/azeroth-survivors"
if [[ -f "$legacy/windows/AzerothSurvivors/AzerothSurvivors.exe" ]]; then
  state="$legacy"
  game="$legacy/windows/AzerothSurvivors"
else
  state="${XDG_DATA_HOME:-$HOME/.local/share}/azeroth-survivors"
  game="$state/game"
  mkdir -p "$state"
  # Serialize initial installation; interruption leaves no half-installed game.
  exec 9>"$state/install.lock"
  flock 9
  if [[ ! -f "$game/AzerothSurvivors.exe" ]]; then
    staging=$(mktemp -d "$state/install.XXXXXXXX")
    trap 'rm -rf "$staging"' EXIT
    cp -R --reflink=auto @PAYLOAD@/. "$staging/"
    chmod -R u+w "$staging"
    mv "$staging" "$game"
    trap - EXIT
  fi
  flock -u 9
  exec 9>&-
fi
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
mkdir -p "$state/proton-prefix" "$STEAM_COMPAT_CLIENT_INSTALL_PATH"
export STEAM_COMPAT_DATA_PATH="$state/proton-prefix"
export SteamAppId=0
export SteamGameId=0
export WGPU_BACKEND=vulkan
export PROTON_LOG=1
export PROTON_LOG_DIR="$state"
# Keep the runtime already tested on the user's machine; bundle one for fresh installs.
proton=@PROTON@
for version in "Proton - Experimental" "Proton Hotfix"; do
  candidate="$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/common/$version/proton"
  if [[ -f "$candidate" ]]; then
    proton="$candidate"
    break
  fi
done
cd "$game"
exec steam-run "$proton" run "$game/AzerothSurvivors.exe" "$@"
