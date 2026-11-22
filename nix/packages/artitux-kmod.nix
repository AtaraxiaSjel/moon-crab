# artitux_kmod: the kernel module from the artitux repo — per-process UMIP
# (SGDT/SIDT) fixup and lazy userspace XCR0=0x7 for VBS 2.0 releases, exposed
# via /dev/artitux.
#
# The version tracks the repo pin (versions.json stays the single source);
# the module's own MODULE_VERSION lives in kmod/main.c (0.1.3 at v1.1.2).
# The upstream Makefile has no plain install target (only DKMS), so the .ko
# is installed manually; the userspace helper (make cli) is not packaged —
# this flake never runs it, same as slsteam-moon's pattern-refresh.
{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
}:
let
  v = (lib.importJSON ../versions.json).artitux;
in
stdenv.mkDerivation {
  pname = "artitux-kmod";
  version = "${v.version}-${kernel.version}";

  src = fetchFromGitHub {
    owner = v.owner;
    repo = v.repo;
    rev = v.rev;
    hash = v.hash;
  };

  sourceRoot = "source/kmod";

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags ++ [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall
    install -Dm644 artitux_kmod.ko -t "$out/lib/modules/${kernel.modDirVersion}/"
    runHook postInstall
  '';

  meta = {
    description = "artitux_kmod: per-process UMIP fixup and XCR0=0x7 kernel module for Artitux";
    homepage = "https://github.com/${v.owner}/${v.repo}";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
}
