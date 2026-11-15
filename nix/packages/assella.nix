# ASSella (Steam game and depot management suite) from its release AppImage.
# Modeled on the ataraxiadev enter-the-wired packaging: extract icon/desktop
# from the AppImage itself, wrap with wrapType2, then strip the Qt plugin env
# (a leaked QT_PLUGIN_PATH mixes nixpkgs Qt plugins into the bundled PyQt6 and
# dies on version-mismatched private-ABI symbols in KDE sessions).
{
  lib,
  fetchurl,
  appimageTools,
  runCommand,
  makeWrapper,
}:
let
  v = (lib.importJSON ../versions.json).assella;
  pname = "assella";
  src = fetchurl {
    url = "https://github.com/${v.owner}/${v.repo}/releases/download/${v.tag}/${v.asset}";
    hash = v.hash;
  };
  contents = appimageTools.extract {
    inherit pname src;
    version = v.version;
  };
  wrapped = appimageTools.wrapType2 {
    inherit pname src;
    version = v.version;
    extraPkgs =
      pkgs: with pkgs; [
        icu
        xcb-util-cursor
        zstd
      ];
    extraInstallCommands = ''
      install -m 444 -D "${contents}/assella.png" "$out/share/pixmaps/assella.png"
      install -m 444 -D "${contents}/assella.desktop" "$out/share/applications/assella.desktop"
      substituteInPlace "$out/share/applications/assella.desktop" \
        --replace-fail 'Exec=AppRun' 'Exec=assella'
    '';
    meta = with lib; {
      description = "Steam game and depot management suite";
      homepage = "https://github.com/${v.owner}/${v.repo}";
      platforms = platforms.linux;
      mainProgram = pname;
    };
  };
in
runCommand "${pname}-${v.version}"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta = {
      description = "Steam game and depot management suite";
      homepage = "https://github.com/${v.owner}/${v.repo}";
      platforms = [ "x86_64-linux" ];
      mainProgram = pname;
    };
  }
  ''
    mkdir -p $out/bin
    cp -r ${wrapped}/share $out/share
    makeWrapper ${wrapped}/bin/${pname} $out/bin/${pname} \
      --unset QT_PLUGIN_PATH \
      --unset QT_QPA_PLATFORM_PLUGIN_PATH \
      --unset QTWEBKIT_PLUGIN_PATH \
      --unset QML2_IMPORT_PATH
  ''
