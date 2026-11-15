# SLSsteam from upstream's own release 7z: one 64-bit audit object plus the
# res/config.yaml it was built against (the managed config's merge base).
#
# The prebuilt object links only libcurl/libdbus beyond the standard libs —
# both supplied by the Steam runtime it is loaded into — so no patchelf, no
# rpath surgery. A future release growing a NEEDED entry the Steam runtime
# does not ship means switching this entry to a source build.
{
  lib,
  runCommand,
  fetchurl,
  p7zip,
  binutils,
}:
let
  v = lib.importJSON ../versions.json;
  u = v.slssteam;
  src = fetchurl {
    url = "https://github.com/${u.owner}/${u.repo}/releases/download/${u.tag}/${u.asset}";
    hash = u.hash;
  };
  drv =
    runCommand "SLSsteam-${u.version}"
      {
        nativeBuildInputs = [
          p7zip
          binutils
        ];
        meta = {
          description = "Steamclient modification for Linux";
          homepage = "https://github.com/${u.owner}/${u.repo}";
          license = lib.licenses.agpl3Only;
          platforms = [ "x86_64-linux" ];
        };
      }
      ''
        mkdir -p "$out/lib" "$out/res"
        7z x ${src} -y -oart > /dev/null
        install -m 644 art/bin/SLSsteam.so "$out/lib/SLSsteam.so"
        install -m 644 art/res/config.yaml "$out/res/config.yaml"

        # Guard against a future release pulling in a library the Steam runtime
        # does not ship: fail loudly here instead of crashing the client there.
        if readelf -d "$out/lib/SLSsteam.so" | grep -Eq 'libcrypto|libssl'; then
          echo "error: SLSsteam.so now links a library the Steam runtime may not ship" >&2
          exit 1
        fi
      '';
in
drv
// {
  defaultConfig = "${drv}/res/config.yaml";
  ldAudit = "${drv}/lib/SLSsteam.so";
}
