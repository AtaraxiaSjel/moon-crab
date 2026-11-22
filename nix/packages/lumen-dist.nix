# Lumen built from source: the `lumen` binary plus its lua/ tree — the same
# runtime layout the release zip ships.
#
# Source, not the release zip, because the steamrt64 peerauth fix ("accept
# steamrt64 and steamrt32 client paths") lives on main while the newest
# release (v2.9) predates the 64-bit client; without it Lumen refuses to
# attach to the steamrt64 CEF listener. The Makefile falls back to dynamic
# linking when its static-archive probes miss (they do in the sandbox):
# pkg-config provides lua5.4 and libcurl, and the stdenv rpath carries the
# lot — fine on NixOS, where the binary runs natively next to /nix/store.
{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  lua5_4,
  curl,
  openssl,
}:
let
  v = lib.importJSON ../versions.json;
  u = v.lumen;
in
stdenv.mkDerivation {
  pname = "lumen";
  version = u.version;

  src = fetchFromGitHub {
    owner = u.owner;
    repo = u.repo;
    rev = u.rev;
    hash = u.hash;
  };

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    lua5_4
    curl
    openssl
  ];

  buildPhase = ''
    runHook preBuild
    make bin/lumen
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    install -m 0755 bin/lumen $out/lumen
    cp -r lua $out/lua
    runHook postInstall
  '';

  meta = {
    description = "Lumen backend (slsteam-moon LuaTools stack)";
    homepage = "https://github.com/${u.owner}/${u.repo}";
    license = lib.licenses.unfree;
    maintainers = [ lib.maintainers.ataraxiasjel ];
    platforms = [ "x86_64-linux" ];
  };
}
