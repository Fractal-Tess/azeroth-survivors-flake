<p align="center"><img src="assets/logo.svg" alt="Azeroth Survivors plus Nix" width="480" /></p>
<p align="center"><a href="https://wow.aethus.pl/"><img src="https://img.shields.io/badge/game-Aethus-gold" alt="Original game by Aethus" /></a> <img src="https://img.shields.io/badge/Nix-flake-5277c3" alt="Nix flake" /></p>
<h1 align="center">Azeroth Survivors for Nix</h1>
<p align="center">The official Windows game, ready to launch on Linux through Proton.</p>

Packages Aethus's game with a desktop launcher, a Proton runtime and the Vulkan setting used on our Linux machines. First launch creates a writable installation so the game's updater can work. Existing installations in `~/Games/azeroth-survivors` keep their updates, prefix and saves.

## Play

```sh
nix run github:Fractal-Tess/azeroth-survivors-flake
```

Supports **x86_64 Linux**. The pinned Windows archive is about 755 MB; its extracted data and Proton need several GB. The bootstrap archive may lag behind the in-game release; use the game's **Download & restart** prompt for newer releases. This packages the original binary, not the separate source reconstruction.

## NixOS or Home Manager

```nix
inputs.azeroth-survivors = {
  url = "github:Fractal-Tess/azeroth-survivors-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import `inputs.azeroth-survivors.nixosModules.default` into NixOS, or `inputs.azeroth-survivors.homeManagerModules.default` into Home Manager. Then enable:

```nix
programs.azeroth-survivors.enable = true;
```

The application menu entry is **Azeroth Survivors (Proton)**. Fresh installations live under `${XDG_DATA_HOME:-~/.local/share}/azeroth-survivors`; existing manual installations keep their current paths. The launcher prefers Steam's installed Proton Experimental or Hotfix, with a bundled GE-Proton fallback. It creates a separate Proton prefix; Steam itself does not need to be running.

The repository is also mirrored on the private Gitadel forge.

## Automation

GitHub builds every push and pull request. A daily updater checks the official archive ETag, verifies any new archive by SHA-256 and builds it before committing new pins. Unchanged releases are also checked. The range downloader works around the developer server's slow single-connection transfer rate. It never mirrors game files to this repository.

## Packaging notes

`nix build` builds the launcher and game payload. `nix flake check` also checks the modules and launcher behavior. The archive is fetched directly from the developer and verified with a fixed hash. If the developer replaces that URL's contents, update the hash and base version in `packages/azeroth-survivors.nix`; Nix will reject mismatched downloads.

Game binaries, game data archives and Proton prefixes are never committed to this repository. Packaging code is [MIT licensed](LICENSE); the game and Warcraft artwork retain their owners' rights. [Aethus's original game](https://wow.aethus.pl/) is not affiliated with Blizzard. The README logo combines the original game icon, extracted from the official Windows executable, with the [Nix snowflake](https://github.com/NixOS/nixos-artwork/blob/master/logo/nix-snowflake-colours.svg) by Simon Frankau and Tim Cuthbertson ([CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)). Both marks retain their original artwork and colors; they were resized and arranged with a plus sign. Game artwork retains its owners' rights; the packaging license does not cover it. This is an unofficial package.
