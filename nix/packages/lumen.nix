# Store entry point for an installed Lumen backend. The backend itself lives
# under ~/.local/share/Lumen (it writes state at runtime); this script only
# knows how to start it: inside steam-run, with the 32-bit loader env dropped
# (those carry the slsteam-moon hooks, and steam-run sources the Steam FHS
# profile, so unsetting them outside would be a no-op while 64-bit Lumen and
# every backend script it spawns get "wrong ELF class" from ld.so).
{ writeShellScriptBin, steam-run }:
writeShellScriptBin "lumen" ''
  dir="$HOME/.local/share/Lumen"
  if [ ! -x "$dir/lumen.bin" ]; then
    echo "lumen: backend not installed (enable programs.moon-crab.luatools first)" >&2
    exit 1
  fi
  cd "$dir" || exit 1
  export LUMEN_BACKEND_DIR="$PWD/luatools/backend"
  export LUMEN_LUA_DIR="$PWD/lua"
  exec ${steam-run}/bin/steam-run env -u LD_AUDIT -u LD_PRELOAD ./lumen.bin "$@"
''
