# Artitux: the launcher + Artitux.so from the injected overlay namespace.
# artitux_kmod always builds against the SYSTEM kernel: kernelPackages.callPackage
# injects kernel + kernelModuleMakeFlags (a kernel module must match its kernel).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.moon-crab;
  pkg = pkgs.moon-crab.artitux;
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.artitux.enable {
      environment.systemPackages = [ pkg ];

      programs.moon-crab.steam.extraPkgs = [ pkg ];
    })

    (lib.mkIf cfg.artitux.kmod.enable {
      boot.extraModulePackages = [
        (config.boot.kernelPackages.callPackage ../packages/artitux-kmod.nix { })
      ];

      boot.kernelModules = lib.mkIf cfg.artitux.kmod.autoload [ "artitux_kmod" ];
    })
  ];
}
