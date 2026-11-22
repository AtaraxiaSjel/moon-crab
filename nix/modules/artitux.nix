# Artitux: the launcher + Artitux.so.
# artitux_kmod is a kernel module built against the system's kernel.
{
  artitux,
  artituxKmod,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.moon-crab;
  pkg = artitux pkgs;
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.artitux.enable {
      environment.systemPackages = [ pkg ];

      programs.moon-crab.steam.extraPkgs = [ pkg ];
    })

    (lib.mkIf cfg.artitux.kmod.enable {
      boot.extraModulePackages = [ (artituxKmod config.boot.kernelPackages) ];

      boot.kernelModules = lib.mkIf cfg.artitux.kmod.autoload [ "artitux_kmod" ];
    })
  ];
}
