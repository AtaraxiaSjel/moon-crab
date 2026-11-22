# LuaTools stack: Lumen backend + LuaTools plugin under ~/.local/share/Lumen.
#
# Both dists are assembled in the store (packages/lumen-dist.nix,
# packages/luatools.nix); the activation copies them into real directories
# because Lumen and the plugin write state at runtime (config, manifest
# packs, logs). The raw binary runs NATIVELY via a shim, never inside
# steam-run (see below).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.moon-crab;
  target = import ../lib/target.nix { inherit config lib; };

  dist = pkgs.moon-crab.lumen-dist;
  plugin = pkgs.moon-crab.luatools;
  entry = pkgs.moon-crab.lumen;

  # `~/.local/share/Lumen/lumen` execs the raw binary NATIVELY (not via
  # steam-run): Lumen's peerauth must resolve the CEF listener's owner through
  # /proc/PID/{exe,fd}, and inside steam-run those readlinks fail, so it
  # refuses to attach ("owner unknown") and no menu button appears. The
  # audit env is still dropped — lumen.bin is a non-Steam process and must
  # never load the SLSsteam audit object. A store file, not a heredoc:
  # copied verbatim into the install dir, so no Nix-string reindentation
  # can ever break it.
  shim = pkgs.writeText "lumen" ''
    #!/bin/sh
    cd "$(dirname "$0")" || exit 1
    export LUMEN_BACKEND_DIR="$PWD/luatools/backend"
    export LUMEN_LUA_DIR="$PWD/lua"
    exec env -u LD_AUDIT -u LD_PRELOAD ./lumen.bin "$@"
  '';

  dir = "${target.home}/.local/share/Lumen";
  stampDir = "${dir}/.moon-crab";

  userScoped = target.user != null;
in
{
  config = lib.mkMerge [
    # A plain command to attach Lumen to an already-running Steam.
    (lib.mkIf (cfg.luatools.enable && userScoped) {
      environment.systemPackages = [ entry ];

      system.activationScripts."moon-crab-luatools" =
        import ../lib/activate.nix
          {
            inherit lib pkgs;
            user = target.user;
            home = target.home;
          }
          "luatools"
          ''
            needsSync() {
              src=$1 dir=$2 stamp=$3
              [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$src" ] && [ -d "$dir" ] && return 1
              return 0
            }

            # Copy a store dist into a writable dir, removing only the files
            # the PREVIOUS dist installed (the stamp holds its store path) so
            # runtime state survives a version bump: cef_port, notifications,
            # and backend/data + backend/temp_dl under the plugin.
            installDist() {
              src=$1 dir=$2 stamp=$3
              run chmod -R u+w "$dir" 2>/dev/null || true
              if [ -f "$stamp" ] && old=$(cat "$stamp") && [ -d "$old" ]; then
                (cd "$old" && find . ! -type d) | while read -r f; do
                  run rm -f "$dir/$f"
                done
              fi
              run mkdir -p "$dir"
              run cp -r "$src"/. "$dir"/
              run chmod -R u+w "$dir"
              # Activation runs as root, so the copied tree (and any
              # preserved runtime state) ends up root-owned and the plugin
              # cannot write (e.g. backend/data/lua_tools_auth.json on
              # login). Hand the whole tree to the user.
              own "$dir"
            }

            writeStamp() {
              run mkdir -p "${stampDir}"
              tmp=$(mktemp)
              printf '%s' "$1" > "$tmp"
              run install -m644 "$tmp" "$2"
              rm -f "$tmp"
            }

            if needsSync "${dist}" "${dir}" "${stampDir}/lumen-src"; then
              installDist "${dist}" "${dir}" "${stampDir}/lumen-src"
              run rm -f "${dir}/lumen.bin"
              run mv "${dir}/lumen" "${dir}/lumen.bin"
              run install -m755 ${shim} "${dir}/lumen"
              writeStamp "${dist}" "${stampDir}/lumen-src"
              echo "moon-crab: installed Lumen backend to ${dir}"
            else
              echo "moon-crab: Lumen backend is up to date"
            fi

            if needsSync "${plugin}" "${dir}/luatools" "${stampDir}/luatools-src"; then
              installDist "${plugin}" "${dir}/luatools" "${stampDir}/luatools-src"
              writeStamp "${plugin}" "${stampDir}/luatools-src"
              echo "moon-crab: installed LuaTools plugin"
            else
              echo "moon-crab: LuaTools plugin is up to date"
            fi

            # Installs predating the own() in installDist left root-owned
            # trees behind with up-to-date stamps, so no reinstall would
            # ever repair them. Reassert ownership on every activation.
            own "${dir}" "${stampDir}"
          '';
    })

    # Steam exposes its CEF remote-debugging endpoint only when this marker
    # exists; without it slsteam-moon has nothing to attach to.
    (lib.mkIf (cfg.luatools.enable && userScoped) {
      system.activationScripts."moon-crab-luatools-cef" =
        import ../lib/activate.nix
          {
            inherit lib pkgs;
            user = target.user;
            home = target.home;
          }
          "luatools-cef"
          ''
            touch "$HOME/.steam/steam/.cef-enable-remote-debugging" 2>/dev/null || true
            touch "$HOME/.steam/debian-installation/.cef-enable-remote-debugging" 2>/dev/null || true
          '';
    })

    # Shadow entry point: launching Steam via `steam` also brings up Lumen
    # (pgrep-guarded; nothing in Lumen is single-instance). Replaced by the
    # systemd unit when service mode is on — two start paths would fight over
    # the same CEF target.
    #
    # The shim wins the system-path collision on bin/steam via hiPrio and
    # execs the real (LD_AUDIT-wrapped) Steam by direct store path — PATH
    # scanning cannot work here since both live in the same directory.
    (lib.mkIf (cfg.luatools.enable && !cfg.luatools.service && userScoped) {
      environment.systemPackages = [
        (lib.hiPrio (
          pkgs.writeShellScriptBin "steam" ''
            LUMEN_DIR="$HOME/.local/share/Lumen"
            if [ -x "$LUMEN_DIR/lumen" ] \
              && ! ${pkgs.procps}/bin/pgrep -f "$LUMEN_DIR/lumen" >/dev/null 2>&1; then
              ${pkgs.util-linux}/bin/setsid "$LUMEN_DIR/lumen" >/dev/null 2>&1 </dev/null &
            fi

            exec "${config.programs.steam.package}/bin/steam" "$@"
          ''
        ))
      ];
    })

    (lib.mkIf (cfg.luatools.enable && cfg.luatools.service) {
      systemd.user.services."moon-crab-lumen" = {
        description = "Lumen backend for LuaTools (slsteam-moon)";
        after = [ "graphical-session.target" ];
        wantedBy = [ "default.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${entry}/bin/lumen";
          Restart = "on-failure";
        };
      };
    })
  ];
}
