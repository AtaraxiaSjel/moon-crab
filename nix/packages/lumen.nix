# Store entry point for an installed Lumen backend. The backend itself lives
# under ~/.local/share/Lumen (it writes state at runtime); this script only
# knows how to start it: NATIVELY, not inside steam-run.
#
# Lumen's peerauth refuses to attach when it cannot resolve the CEF listener's
# owner via /proc/PID/{exe,fd} — and inside steam-run (a bwrap sandbox) those
# readlinks fail, so it logs "refusing to attach ... (owner unknown)" and no
# menu button ever appears. Native launch keeps full /proc visibility; the
# audit env is still dropped (lumen.bin is a non-Steam process and must never
# load the SLSsteam audit object).
{ writeShellScriptBin }:
writeShellScriptBin "lumen" ''
  dir="$HOME/.local/share/Lumen"
  if [ ! -x "$dir/lumen.bin" ]; then
    echo "lumen: backend not installed (enable programs.moon-crab.luatools first)" >&2
    exit 1
  fi
  cd "$dir" || exit 1
  export LUMEN_BACKEND_DIR="$PWD/luatools/backend"
  export LUMEN_LUA_DIR="$PWD/lua"
  exec env -u LD_AUDIT -u LD_PRELOAD ./lumen.bin "$@"
''
