{
  description = "Minimal moon-stack flake: slsteam-moon + Lumen/LuaTools injection, upstream SLSsteam, ASSella";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          # Our own packages are all free, but the eval checks compare against
          # pkgs.steam (unfree), so the check closure needs the flag.
          config.allowUnfree = true;
        };

      builders = {
        slssteam = pkgs: pkgs.callPackage ./nix/packages/slssteam.nix { };
        slsteamMoon = pkgs: pkgs.callPackage ./nix/packages/slsteam-moon.nix { };
        lumenDist = pkgs: pkgs.callPackage ./nix/packages/lumen-dist.nix { };
        luatools = pkgs: pkgs.callPackage ./nix/packages/luatools.nix { };
        lumen = pkgs: pkgs.callPackage ./nix/packages/lumen.nix { };
        assella = pkgs: pkgs.callPackage ./nix/packages/assella.nix { };
      };

      nixosModule = {
        imports = [
          ./nix/modules/options.nix
          (import ./nix/modules/slssteam.nix {
            inherit (builders) slssteam slsteamMoon;
          })
          (import ./nix/modules/slssteam-config.nix {
            inherit (builders) slssteam slsteamMoon;
          })
          (import ./nix/modules/luatools.nix {
            inherit (builders) lumenDist luatools lumen;
          })
          (import ./nix/modules/assella.nix { inherit (builders) assella; })
        ];
      };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          slssteam = builders.slssteam pkgs;
          slsteam-moon = builders.slsteamMoon pkgs;
          lumen = builders.lumen pkgs;
          luatools = builders.luatools pkgs;
          lumen-dist = builders.lumenDist pkgs;
          assella = builders.assella pkgs;
          default = builders.slsteamMoon pkgs;
        }
      );

      nixosModules.default = nixosModule;

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          lib = nixpkgs.lib;

          evalSystem =
            extraModule:
            lib.nixosSystem {
              inherit system;
              modules = [
                self.nixosModules.default
                {
                  nixpkgs.config.allowUnfree = true;
                  users.users.alice.isNormalUser = true;
                  programs.moon-crab.user = "alice";
                  boot.loader.grub.enable = false;
                  fileSystems."/" = {
                    device = "/dev/null";
                    fsType = "tmpfs";
                  };
                }
                extraModule
              ];
            };

          # A passing eval test: compute the probe string at eval time, fail
          # the build if it comes out empty.
          expect =
            name: probe:
            pkgs.runCommand "check-${name}" { } ''
              probe=${lib.escapeShellArg probe}
              [ -n "$probe" ] || { echo "${name}: probe is empty" >&2; exit 1; }
              echo "${name}: $probe" > $out
            '';

          bare = evalSystem { };
          fullMoon = evalSystem {
            programs.moon-crab.slssteam.enable = true;
            programs.moon-crab.slssteam.flavor = "moon";
            programs.moon-crab.slssteam.settings = {
              DisableCloud = true;
            };
            programs.moon-crab.luatools.enable = true;
            programs.moon-crab.assella = true;
          };
          # luatools on the upstream flavor must fail evaluation.
          badCombo = builtins.tryEval (
            (evalSystem { programs.moon-crab.luatools.enable = true; }).config.system.build.toplevel.drvPath
          );
        in
        {
          eval-bare-steam-off = expect "bare-steam-off" (
            if !(bare.config.programs.steam.enable or false) then "off" else ""
          );
          eval-full-steam-on = expect "full-steam-on" (
            if fullMoon.config.programs.steam.enable then "on" else ""
          );
          eval-full-ld-audit = expect "full-ld-audit" (
            # steam.override produces a new derivation: a changed drvPath
            # proves our LD_AUDIT override was applied (extraEnv is baked
            # into the FHS profile script, invisible to pure eval).
            if fullMoon.config.programs.steam.package.drvPath != pkgs.steam.drvPath then "moon" else ""
          );
          eval-full-activation = expect "full-activation" (
            if
              (fullMoon.config.system.activationScripts ? "moon-crab-luatools")
              && (fullMoon.config.system.activationScripts ? "moon-crab-slssteam-config")
              && (fullMoon.config.system.activationScripts ? "moon-crab-assella")
            then
              "present"
            else
              ""
          );
          eval-bad-combo-fails = expect "bad-combo-fails" (if !badCombo.success then "rejected" else "");
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
