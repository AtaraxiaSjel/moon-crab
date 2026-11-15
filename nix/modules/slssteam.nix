# SLSsteam injection: one override of the Steam package carrying LD_AUDIT
# from the active flavor.
#
# The two flavors ship asymmetric artefacts (upstream: one SLSsteam.so, moon:
# library-inject.so + SLSsteam.so), but both package builders expose the same
# `ldAudit` attribute — so this module has no flavor branches, only one path
# selection. slssteam-config.nix owns the declarative config.yaml half.
{ slssteam, slsteamMoon }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.moon-crab;
  steamCfg = cfg.steam;

  sls = if cfg.slssteam.flavor == "moon" then slsteamMoon pkgs else slssteam pkgs;

  injectionOn = cfg.slssteam.enable || cfg.luatools.enable;

  steamBase = if steamCfg.package != null then steamCfg.package else pkgs.steam;

  steamNeeded = injectionOn;
  steamOn = if steamCfg.enable == null then steamNeeded else steamCfg.enable;

  passthrough = removeAttrs steamCfg [
    "enable"
    "package"
    "extraPkgs"
    "extraEnv"
    "extraBwrapArgs"
  ];

  needsOverride = steamOn && (injectionOn || steamCfg.package != null || steamCfg.extraPkgs != [ ]);

  needsWrap =
    injectionOn
    || steamCfg.extraPkgs != [ ]
    || steamCfg.extraEnv != { }
    || steamCfg.extraBwrapArgs != [ ];
in
{
  config = lib.mkMerge [
    (lib.mkIf steamOn {
      programs.steam.enable = lib.mkDefault true;
    })
    (lib.mkIf (passthrough != { }) { programs.steam = passthrough; })
    (lib.mkIf needsOverride {
      programs.steam.package =
        if steamCfg.package != null && !needsWrap then
          steamCfg.package
        else
          steamBase.override {
            extraPkgs = p: steamCfg.extraPkgs;
            extraEnv =
              lib.optionalAttrs injectionOn {
                LD_AUDIT = sls.ldAudit;
              }
              // steamCfg.extraEnv;
            # bubblewrap starts with a fresh mount namespace where /sys does
            # not exist, so Mesa cannot resolve /sys/class/drm, refuses to
            # load i915/iris, and falls back to llvmpipe; Steam's 32-bit vgui2
            # then gets no GLX visual and fatal-asserts. One read-only bind.
            extraBwrapArgs = [ "--ro-bind /sys /sys" ] ++ steamCfg.extraBwrapArgs;
          };
    })
  ];
}
