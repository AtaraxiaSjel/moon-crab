# moon-crab

Minimal NixOS flake for the moon stack: SLSsteam injection (upstream or the
slsteam-moon fork), Lumen + LuaTools, ASSella, and Artitux.

## Use

```nix
{
  inputs.moon-crab.url = "github:ataraxiasjel/moon-crab";
  # ...
  imports = [ moon-crab.nixosModules.default ];

  programs.moon-crab = {
    slssteam.enable = true;
    slssteam.flavor = "moon"; # "upstream" | "moon" (steamrt64 client)
    luatools.enable = true;      # needs flavor "moon"
    assella = true;              # optional depot downloader
    artitux.enable = true;       # optional Artifact runtime: launcher + Artitux.so
    artitux.kmod.enable = true;  # optional companion kernel module
    artitux.kmod.autoload = true; # default; false keeps it available but loads manually
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
  (injection), `slssteam-config.nix` (config.yaml), `luatools.nix`, `assella.nix`,
  `artitux.nix`.
- `ci/update-versions.sh` — refreshes versions.json from latest GitHub
  releases (tag + hash together, never by hand).
- `.github/workflows/` — `check.yml` (flake check + fmt), `sync.yml` (weekly
  version-bump PR).

## Notes

- All three moon-stack builds compile from source (rev + NAR hash): upstream
  as a 64-bit object, slsteam-moon since v3.0 as the 64-bit object for the
  steamrt64 client (the Makefile dropped `-m32` and `library-inject.so`; the
  ogb4n/slsteam-moon-x64 interim port is retired), and Lumen from main so the
  steamrt64 peerauth fix ships ahead of its next release. NEEDED stays
  minimal (pthread/dl + standard libs); curl resolves via dlopen at runtime.
- lumen and luatools are pinned to main, not to their release zips: the
  steamrt64 fixes landed after v2.9 and have no release yet.
  `ci/update-versions.sh` only moves those pins forward when a new release
  tag appears — it never rolls a HEAD pin back to the tag's rev.
- `programs.moon-crab.steam` is a small typed subset (enable/package/extraPkgs/
  extraEnv/extraBwrapArgs + freeform passthrough), shaped so a future
  steam-config-nix import can extend it without reshaping consumers.
- The Artitux package builds Artitux.so through upstream's own `cargo xtask`
  and generates the launcher by running upstream's install.sh in the builder
  against a local curl shim (no network; the lib path is rewritten to the
  store). Its vendored deps come from the checked-in
  `nix/packages/artitux-cargo.lock` (refreshed by `ci/update-versions.sh`
  from the hash-verified source), so there is no extra hash to bump.
  `artitux-kmod` must be instantiated through a kernelPackages set
  (`kernelPackages.callPackage` injects the kernel); the module option builds
  against the system kernel, the standalone package pins
  `linuxPackages_latest`.
