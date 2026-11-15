# Writes a body into a system activation snippet that runs on every
# nixos-rebuild switch as the resolved user — the home-manager-free way to
# manage ~/. files. The snippet runs with HOME set and two helpers
# in scope (run/own), records failures via _status without aborting the switch.
{
  lib,
  pkgs,
  user,
  home,
}:
name: body: {
  deps = [
    "specialfs"
    "users"
  ];
  text = ''
    #### moon-crab activation snippet: ${name}
    if ! (
      set -eu
      export HOME=${lib.escapeShellArg home}
      export USER=${lib.escapeShellArg user}
      export LOGNAME=${lib.escapeShellArg user}
      export PATH=${
        lib.makeBinPath (
          with pkgs;
          [
            coreutils
            diffutils
            findutils
            gnugrep
            gnused
            gawk
            jq
            unzip
            yq-go
          ]
        )
      }:$PATH
      run() { "$@"; }
      own() {
        if [ "$(id -u)" = 0 ] && id ${lib.escapeShellArg user} >/dev/null 2>&1; then
          chown -R ${lib.escapeShellArg user} "$@" 2>/dev/null || true
        fi
      }
      ${body}
    ); then
      echo "moon-crab: activation snippet '${name}' failed" >&2
      _status=1
    fi
  '';
}
