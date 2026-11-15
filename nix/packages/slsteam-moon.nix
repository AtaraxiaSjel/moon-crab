# slsteam-moon from its own release zip: the two 32-bit injected objects plus
# the res/config.yaml they were built against (the managed config's merge
# base). {ver} in versions.json is the tag without its leading v.
#
# Both objects link only the standard libs the Steam runtime supplies, so no
# patchelf: the readelf guard below fails the build if a future release grows
# a NEEDED entry (libcurl/libssl) the runtime may not ship — that is the
# signal to switch this entry to a source build instead.
{
  lib,
  runCommand,
  fetchurl,
  unzip,
  binutils,
}:
let
  v = lib.importJSON ../versions.json;
  u = v.slsteam-moon;
  nov = builtins.substring 1 (builtins.stringLength u.tag - 1) u.tag;
  asset = builtins.replaceStrings [ "{ver}" ] [ nov ] u.asset;
  src = fetchurl {
    url = "https://github.com/${u.owner}/${u.repo}/releases/download/${u.tag}/${asset}";
    hash = u.hash;
  };
  drv =
    runCommand "slsteam-moon-${u.version}"
      {
        nativeBuildInputs = [
          unzip
          binutils
        ];
        meta = {
          description = "SLSsteam fork with a native Lua manifest importer (slsteam-moon)";
          homepage = "https://github.com/${u.owner}/${u.repo}";
          license = lib.licenses.agpl3Only;
          platforms = [ "x86_64-linux" ];
        };
      }
      ''
        mkdir -p "$out/lib" "$out/res"
        unzip -q ${src}
        install -m 644 slsteam-moon-*/bin/SLSsteam.so slsteam-moon-*/bin/library-inject.so "$out/lib/"
        install -m 644 slsteam-moon-*/res/config.yaml "$out/res/config.yaml"

        for so in "$out"/lib/*.so; do
          if readelf -d "$so" | grep -Eq 'libcrypto|libssl|libcurl'; then
            echo "error: $so now links a library the Steam runtime may not ship" >&2
            exit 1
          fi
        done
      '';
in
drv
// {
  defaultConfig = "${drv}/res/config.yaml";
  ldAudit = "${drv}/lib/library-inject.so:${drv}/lib/SLSsteam.so";
}
