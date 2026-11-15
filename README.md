# moon-crab

Minimal NixOS flake for the moon stack: SLSsteam injection (upstream or the
slsteam-moon fork), Lumen + LuaTools, and ASSella.

## Use

```nix
{
  inputs.moon-crab.url = "github:ataraxiasjel/moon-crab";
  # ...
  imports = [ moon-crab.nixosModules.default ];

  programs.moon-crab = {
    slssteam.enable = true;
    slssteam.flavor = "moon-x64"; # "upstream" | "moon" (32-bit) | "moon-x64" (steamrt64)
    luatools.enable = true;      # needs flavor "moon" or "moon-x64"
    assella = true;              # optional depot downloader
    slssteam.settings = {        # optional declarative config.yaml
      DisableCloud = true;
    };
  };
}
```

No home-manager involved: user-scoped files are written by system activation
snippets on every `nixos-rebuild switch`. With zero or several normal users,
set `programs.moon-crab.user` explicitly.

## Layout

- `nix/versions.json` — every upstream pin (tag + SRI hash). One edit (or one
  `ci/update-versions.sh` run) bumps everything.
- `nix/packages/` — one builder per artefact; both SLSsteam flavors expose the
  same `ldAudit`/`defaultConfig` attributes, so consumers never branch.
- `nix/modules/` — `options.nix` (all options + assertions), `slssteam.nix`
  (injection), `slssteam-config.nix` (config.yaml), `luatools.nix`, `assella.nix`.
- `ci/update-versions.sh` — refreshes versions.json from latest GitHub
  releases (tag + hash together, never by hand).
- `.github/workflows/` — `check.yml` (flake check + fmt), `sync.yml` (weekly
  version-bump PR).

## Notes

- Both SLSsteam builds compile from source (rev + NAR hash): upstream as a
  64-bit object, slsteam-moon as the two 32-bit objects with vendored static
  libs, slsteam-moon-x64 (ogb4n's 64-bit port for the steamrt64 client) as
  one 64-bit object without library-inject.so. NEEDED stays minimal
  (pthread/dl + standard libs); curl resolves via dlopen at runtime.
- `programs.moon-crab.steam` is a small typed subset (enable/package/extraPkgs/
  extraEnv/extraBwrapArgs + freeform passthrough), shaped so a future
  steam-config-nix import can extend it without reshaping consumers.
