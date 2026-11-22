# The complete option surface of this flake, declared once. Other modules in
# this directory own the wiring; this file owns only options (plus the
# cross-feature assertions).
#
# programs.moon-crab.steam is intentionally a small typed subset
# ({enable, package, extraPkgs, extraEnv, extraBwrapArgs} + freeform
# passthrough) so a future steam-config-nix import can extend it without
# reshaping every consumer.
{ config, lib, ... }:
let
  target = import ../lib/target.nix { inherit config lib; };
  cfg = config.programs.moon-crab;

  needsUser = cfg.slssteam.settings != { } || cfg.luatools.enable || cfg.assella;
in
{
  options.programs.moon-crab = {
    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "alice";
      description = ''
        The user the user-scoped features (SLSsteam config, LuaTools, ASSella)
        are configured for. Leave unset when the system has exactly one normal
        user — that one is used. With zero or several normal users, set it
        explicitly.
      '';
    };

    steam = lib.mkOption {
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf lib.types.anything;
        options = {
          enable = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = ''
              Whether the Steam client is enabled. Leave unset (null) and the
              features turn it on themselves when they need it; set true to
              install Steam without them, false to force it off (features that
              need it then fail evaluation instead of silently doing nothing).
            '';
          };
          package = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default = null;
            description = ''
              The Steam package everything is built on. Null means pkgs.steam;
              injection and extraPkgs are applied on top of whatever is set.
            '';
          };
          extraPkgs = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = "Extra libraries for the Steam FHS environment.";
          };
          extraEnv = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Extra environment for the Steam wrapper.";
          };
          extraBwrapArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra bubblewrap arguments for the Steam wrapper.";
          };
        };
      };
      default = { };
      description = ''
        The Steam client. enable = null (default) lets features turn Steam on
        when they need it; package/extraPkgs/extraEnv/extraBwrapArgs are
        applied on top of the package. Anything else is forwarded verbatim to
        programs.steam (freeform passthrough).
      '';
    };

    slssteam = {
      enable = lib.mkEnableOption "SLSsteam injection into Steam";
      flavor = lib.mkOption {
        type = lib.types.enum [
          "upstream"
          "moon"
        ];
        default = "upstream";
        example = "moon";
        description = ''
          Which SLSsteam build to inject: upstream AceSLS/SLSsteam, or the
          slsteam-moon fork with a native Lua manifest importer (required by
          luatools).
        '';
      };
      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        example = {
          PlayNotOwnedGames = true;
          DisableCloud = true;
        };
        description = ''
          Declarative SLSsteam configuration. Anything written here is merged
          over the active flavor's own default config and written to
          ~/.config/SLSsteam/config.yaml as a real file (not a store
          symlink), so SLSsteam and the LuaTools plugin can keep writing to
          it. Leave empty to leave the file alone entirely.
        '';
      };
    };

    luatools = {
      enable = lib.mkEnableOption ''
        the LuaTools stack for the moon flavor: Lumen (backend) plus the
        LuaTools plugin under ~/.local/share/Lumen, with a `lumen` launcher
        command. Requires slssteam flavor "moon".
      '';
      service = lib.mkEnableOption ''
        running Lumen as a systemd user service (starts at login,
        Restart=on-failure) instead of the steam-wrapper sidecar.
      '';
    };

    assella = lib.mkEnableOption "ASSella (Steam depot downloader)";

    artitux = {
      enable = lib.mkEnableOption ''
        Artitux (LD_PRELOAD runtime for Artifact releases): installs the
        launcher plus Artitux.so system-wide and into the Steam environment.
      '';
      kmod = {
        enable = lib.mkEnableOption ''
          The artitux_kmod kernel module: per-process UMIP (SGDT/SIDT) fixup
          and lazy userspace XCR0=0x7 for VBS 2.0 releases, exposed as
          /dev/artitux.
        '';
        autoload = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Add artitux_kmod to boot.kernelModules so it loads at boot.
          '';
        };
      };
    };
  };

  config.assertions = [
    {
      assertion = !cfg.luatools.enable || cfg.slssteam.flavor == "moon";
      message = ''
        programs.moon-crab.luatools.enable requires
        programs.moon-crab.slssteam.flavor = "moon": the Lumen backend
        drives slsteam-moon's Lua manifest importer, which upstream
        SLSsteam lacks.
      '';
    }
    {
      assertion = cfg.user == null || config.users.users ? ${cfg.user};
      message = ''
        programs.moon-crab.user is set to "${toString cfg.user}", but
        users.users.${toString cfg.user} does not exist. Declare the user
        first (users.users.<name>.isNormalUser = true).
      '';
    }
    {
      assertion = !needsUser || target.user != null;
      message = ''
        moon-crab: a user-scoped option is set, but no target user resolves
        (zero or several normal users on this system). Set
        programs.moon-crab.user = "<name>";.
      '';
    }
  ];
}
