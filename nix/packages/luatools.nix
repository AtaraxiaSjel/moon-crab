# The LuaTools plugin built from the canonical source tree: upstream's own
# scripts/build.sh packages plugin/ verbatim (plugin.json, backend/, public/),
# dropping only runtime state that a fresh checkout never has. Source, not
# the release zip, because the 64-bit Steam installer fixes live on main
# while the newest release (v2.9) predates them. The build script's optional
# lua_tools_fix_index.json refresh needs network; the committed copy ships.
{
  lib,
  stdenv,
  fetchFromGitHub,
}:
let
  v = lib.importJSON ../versions.json;
  u = v.luatools;
in
stdenv.mkDerivation {
  pname = "luatools";
  version = u.version;

  src = fetchFromGitHub {
    owner = u.owner;
    repo = u.repo;
    rev = u.rev;
    hash = u.hash;
  };

  # build.sh needs python3 for its manifest refresh + validation steps; the
  # copy itself is plain cp, so keep the build dependency-free and mirror the
  # script's packaging part by hand.
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r plugin/. $out/
    chmod +x $out/backend/scripts/*.sh $out/backend/bin/7zz
    runHook postInstall
  '';

  meta = {
    description = "LuaTools plugin (slsteam-moon LuaTools stack)";
    homepage = "https://github.com/${u.owner}/${u.repo}";
    license = lib.licenses.agpl3Only;
    maintainers = [ lib.maintainers.ataraxiasjel ];
    platforms = [ "x86_64-linux" ];
  };
}
