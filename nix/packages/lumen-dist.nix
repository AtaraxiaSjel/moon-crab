# Lumen's release zip is already the runtime layout: the `lumen` binary plus
# its lua/ tree.
{
  lib,
  runCommand,
  fetchurl,
  unzip,
}:
let
  v = lib.importJSON ../versions.json;
  u = v.lumen;
  src = fetchurl {
    url = "https://github.com/${u.owner}/${u.repo}/releases/download/${u.tag}/${u.asset}";
    hash = u.hash;
  };
in
runCommand "lumen-${u.version}"
  {
    meta = {
      description = "Lumen backend (slsteam-moon LuaTools stack)";
      homepage = "https://github.com/${u.owner}/${u.repo}";
      platforms = [ "x86_64-linux" ];
    };
  }
  ''
    mkdir -p $out
    ${unzip}/bin/unzip -qo ${src} -d $out
    chmod +x $out/lumen
  ''
