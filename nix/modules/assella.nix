# ASSella desktop app: the release AppImage wrapped with wrapType2 (see
# packages/assella.nix), plus a seeded ACCELA.conf.
#
# Seeded, not managed: QSettings rewrites this file, so a store symlink would
# break; the seed only lands when the file does not exist yet, with the same
# keys ASSella's own installer forces (making it defer to SLSsteam).
{ assella }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.moon-crab;
  target = import ../lib/target.nix { inherit config lib; };

  pkg = assella pkgs;

  seed = pkgs.writeText "ACCELA.conf" ''
    [General]
    auto_skip_single_choice=true
    library_mode=true
    max_downloads=16
    sls_config_management=true
    slssteam_mode=true
    use_steamless=true
  '';

  userScoped = target.user != null;
in
{
  config = lib.mkIf (cfg.assella && userScoped) {
    environment.systemPackages = [ pkg ];

    system.activationScripts."moon-crab-assella" =
      import ../lib/activate.nix
        {
          inherit lib pkgs;
          user = target.user;
          home = target.home;
        }
        "assella"
        ''
          conf="$HOME/.config/Tachibana Labs/ACCELA.conf"
          if [ ! -e "$conf" ]; then
            mkdir -p "$(dirname "$conf")"
            install -m 644 ${seed} "$conf"
            own "$(dirname "$conf")"
            echo "moon-crab: seeded ACCELA.conf"
          fi
        '';
  };
}
