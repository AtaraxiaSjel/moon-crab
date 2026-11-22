# slsteam-moon built from source: the single 64-bit audit object plus the
# res/config.yaml from the same tree (the managed config's merge base).
#
# Since v3.0 the main project targets the steamrt64 client natively: the
# Makefile is 64-bit (no -m32) and library-inject.so is gone — a 32-bit
# libcurl redirect has no business in the 64-bit client, and the fork that
# carried the x86_64 port (ogb4n/slsteam-moon-x64) is therefore retired.
# The link needs only -lpthread -ldl: libcurl is resolved via dlopen at
# runtime (curl/curl.h is compile-only) and luajit is a vendored static
# archive (luajit headers are compile-only, for the Lua hook signatures).
{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  patchelf,
  curl,
  luajit,
}:
let
  v = lib.importJSON ../versions.json;
  u = v.slsteam-moon;
  drv = stdenv.mkDerivation {
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

    buildInputs = [
      curl
      luajit
    ];

    postPatch = ''
      patchShebangs embed-config.sh
    '';

    # audit object only: pattern-refresh is a native host helper this flake
    # never runs.
    buildPhase = ''
      runHook preBuild
      make bin/SLSsteam.so
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
      description = "SLSsteam fork with a native Lua manifest importer (slsteam-moon)";
      homepage = "https://github.com/${u.owner}/${u.repo}";
      license = lib.licenses.agpl3Only;
      maintainers = [ lib.maintainers.ataraxiasjel ];
      platforms = [ "x86_64-linux" ];
    };
  };
in
drv
// {
  defaultConfig = "${drv}/res/config.yaml";
  ldAudit = "${drv}/lib/SLSsteam.so";
}
