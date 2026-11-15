# The LuaTools plugin's release zip is the canonical plugin tree
# (plugin.json, backend/, public/), already stripped of runtime state.
{
  lib,
  runCommand,
  fetchurl,
  unzip,
}:
let
  v = lib.importJSON ../versions.json;
  u = v.luatools;
  src = fetchurl {
    url = "https://github.com/${u.owner}/${u.repo}/releases/download/${u.tag}/${u.asset}";
    hash = u.hash;
  };
in
runCommand "luatools-${u.version}"
  {
    meta = {
      description = "LuaTools plugin (slsteam-moon LuaTools stack)";
      homepage = "https://github.com/${u.owner}/${u.repo}";
      platforms = [ "x86_64-linux" ];
    };
  }
  ''
    mkdir -p $out
    ${unzip}/bin/unzip -qo ${src} -d $out
    chmod +x $out/backend/scripts/*.sh $out/backend/bin/7zz
  ''
