# slsteam-moon built from source: the two 32-bit injected objects plus the
# res/config.yaml from the same tree (the managed config's merge base).
#
# The link needs only -lpthread -ldl: libcurl is resolved via dlopen at
# runtime and SHA256 is a vendored implementation (openssl headers are
# compile-only, for sha.h constants). Only the two Steam-loaded i386
# objects are built — pattern-refresh is a native host helper, never run.
{
  lib,
  fetchFromGitHub,
  pkgsi686Linux,
  pkg-config,
  patchelf,
}:
let
  v = lib.importJSON ../versions.json;
  u = v.slsteam-moon;
  drv = pkgsi686Linux.stdenv.mkDerivation {
    pname = "slsteam-moon";
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

    buildInputs = with pkgsi686Linux; [
      curl
      openssl
    ];

    env.NIX_CFLAGS_COMPILE = "-include cstdint";

    postPatch = ''
      patchShebangs embed-version.sh embed-config.sh
    '';

    buildPhase = ''
      runHook preBuild
      make bin/SLSsteam.so bin/library-inject.so
      runHook postBuild
    '';

    enableParallelBuilding = true;

    installPhase = ''
      runHook preInstall
      install -D bin/SLSsteam.so bin/library-inject.so -t $out/lib/
      install -D res/config.yaml -t $out/res/
      runHook postInstall
    '';

    postFixup = ''
      patchelf --remove-rpath $out/lib/SLSsteam.so
      patchelf --remove-rpath $out/lib/library-inject.so
    '';

    meta = {
      description = "SLSsteam fork with a native Lua manifest importer (slsteam-moon)";
      homepage = "https://github.com/${u.owner}/${u.repo}";
      license = lib.licenses.agpl3Only;
      # Host here is i686 (pkgsi686Linux toolchain); the output only ever
      # lands on x86_64 systems next to a 64-bit Steam, but the derivation
      # itself must accept the i686 host.
      platforms = lib.platforms.linux;
    };
  };
in
drv
// {
  defaultConfig = "${drv}/res/config.yaml";
  ldAudit = "${drv}/lib/library-inject.so:${drv}/lib/SLSsteam.so";
}
