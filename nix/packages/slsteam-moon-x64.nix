# slsteam-moon-x64 built from source: the single 64-bit audit object plus
# the res/config.yaml from the same tree (the managed config's merge base).
#
# ogb4n's 64-bit-only port of slsteam-moon for the steamrt64 client: ARCH
# selects the x86_64 code paths, vendored static libs come from lib/x86_64,
# and library-inject.so is deliberately not built — the fork's own setup.sh
# skips it for ELF64 builds (a 32-bit libcurl redirect has no business in the
# 64-bit client). The link needs only -lpthread -ldl: libcurl is resolved via
# dlopen at runtime and SHA256 is a vendored implementation (openssl headers
# are compile-only, for sha.h constants).
{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  patchelf,
  curl,
  openssl,
}:
let
  v = lib.importJSON ../versions.json;
  u = v.slsteam-moon-x64;
  drv = stdenv.mkDerivation {
    pname = "slsteam-moon-x64";
    version = u.version;

    src = fetchFromGitHub {
      owner = u.owner;
      repo = u.repo;
      rev = u.rev;
      hash = u.hash;
    };

    nativeBuildInputs = [
      pkg-config
      patchelf
    ];

    buildInputs = [
      curl
      openssl
    ];

    env.NIX_CFLAGS_COMPILE = "-include cstdint";

    postPatch = ''
      patchShebangs embed-version.sh embed-config.sh
    '';

    buildPhase = ''
      runHook preBuild
      make bin/SLSsteam.so ARCH=x86_64
      runHook postBuild
    '';

    enableParallelBuilding = true;

    installPhase = ''
      runHook preInstall
      install -D bin/SLSsteam.so -t $out/lib/
      install -D res/config.yaml -t $out/res/
      runHook postInstall
    '';

    postFixup = ''
      patchelf --remove-rpath $out/lib/SLSsteam.so
    '';

    meta = {
      description = "64-bit slsteam-moon port for the steamrt64 Steam client (ogb4n fork)";
      homepage = "https://github.com/${u.owner}/${u.repo}";
      license = lib.licenses.agpl3Only;
      platforms = [ "x86_64-linux" ];
    };
  };
in
drv
// {
  defaultConfig = "${drv}/res/config.yaml";
  ldAudit = "${drv}/lib/SLSsteam.so";
}
