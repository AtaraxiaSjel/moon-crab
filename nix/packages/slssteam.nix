# SLSsteam built from source: one 64-bit audit object plus the
# res/config.yaml from the same tree (the managed config's merge base).
#
# Only curl/dbus/luajit come from nixpkgs — protobuf, yaml-cpp, libmem and
# LuaBridge are vendored (lib/x86_64, include/). GIT_COMMIT_HASH bakes the
# pinned rev into the binary (the sandbox has no .git).
{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  patchelf,
  curl,
  dbus,
  luajit,
}:
let
  v = lib.importJSON ../versions.json;
  u = v.slssteam;
  drv = stdenv.mkDerivation {
    pname = "SLSsteam";
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
      dbus
      luajit
    ];

    env.GIT_COMMIT_HASH = u.rev;

    postPatch = ''
      patchShebangs embed-version.sh embed-config.sh
    '';

    # audit-libs only: the tools target needs dotnet, and neither
    # ticket-grabber nor schema-grabber is injected into Steam.
    # JOBS follows the sandbox allocation instead of the Makefile's nproc.
    buildPhase = ''
      runHook preBuild
      make audit-libs "JOBS=$NIX_BUILD_CORES"
      runHook postBuild
    '';

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
      description = "Steamclient modification for Linux";
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
