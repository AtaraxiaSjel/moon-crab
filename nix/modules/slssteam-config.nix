# User-scoped half of SLSsteam: the declarative config.yaml.
#
# settings (options.nix) is merged over the active flavor's own default config
# with yq-go; the result lands at ~/.config/SLSsteam/config.yaml as a real
# file (SLSsteam's watcher and the LuaTools plugin rewrite it at runtime, so
# a store symlink would silently break). The LuaTools plugin owns ManifestPins
# and FakeAppIds between switches — those keys are carried over from the live
# file on every activation unless the user declared them (a declared key is
# the user's, and resetting it is the point).
{
  slssteam,
  slsteamMoon,
  slsteamMoonX64,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.moon-crab;
  target = import ../lib/target.nix { inherit config lib; };

  active =
    if cfg.slssteam.flavor == "moon" then
      slsteamMoon pkgs
    else if cfg.slssteam.flavor == "moon-x64" then
      slsteamMoonX64 pkgs
    else
      slssteam pkgs;
  forkDefault = active.defaultConfig;

  managed =
    if cfg.slssteam.settings == { } then
      forkDefault
    else
      pkgs.runCommand "config.yaml"
        {
          nativeBuildInputs = [ pkgs.yq-go ];
          # strings are JSON-escaped here, YAML-safe after yq decoding below.
          overlayJson = builtins.toJSON cfg.slssteam.settings;
          passAsFile = [ "overlayJson" ];
        }
        ''
          # formats.yaml.generate is not relied on (API differs across
          # channels): overlay starts as JSON and is normalized to plain
          # block-style YAML. yq -P alone only reformats the outer flow doc,
          # inner values stay flow and quoted keys leak through — and "Key" !=
          # Key in YAML, so quoted keys would miss the base doc entirely.
          # Strip the quotes with sed. NOTE: no explode() on the merge — it
          # re-emits both sides as separate flow docs instead of merging.
          yq -P '.' "$overlayJsonPath" > overlay.flow.yaml
          sed -E -e 's/^([[:space:]]*)"([A-Za-z0-9_.-]+)":/\1\2:/' \
            -e 's/([{,][[:space:]]*)"([A-Za-z0-9_.-]+)":/\1\2:/g' \
            overlay.flow.yaml > overlay.norm.yaml
          sed -E "s/^([[:space:]]*)['\"]([0-9]+)['\"]:/\1\2:/" \
            overlay.norm.yaml > overlay.yaml
          yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
            ${forkDefault} overlay.yaml > $out
        '';

  declaredKeys = builtins.attrNames cfg.slssteam.settings;
  preserveKeys = builtins.filter (k: !(builtins.elem k declaredKeys)) [
    "ManifestPins"
    "FakeAppIds"
  ];
  preserveExpr = "with_entries(select((${
    lib.concatStringsSep " or " (map (k: ".key == \"${k}\"") preserveKeys)
  }) and .value != null))";

  file = "${target.home}/.config/SLSsteam/config.yaml";
  userScoped = target.user != null;
in
{
  config = lib.mkIf (cfg.slssteam.settings != { } && userScoped) {
    system.activationScripts."moon-crab-slssteam-config" =
      import ../lib/activate.nix
        {
          inherit lib pkgs;
          user = target.user;
          home = target.home;
        }
        "slssteam-config"
        ''
          target="${file}"
          src="${managed}"
          candidate="$target.tmp.moon-crab"

          mkdir -p "$(dirname "$target")"
          install -m 644 "$src" "$candidate"
          ${
            if preserveKeys == [ ] then
              "true"
            else
              ''
                if [ -f "$target" ]; then
                  runtime_overlay="$target.tmp.moon-crab.runtime"
                  {
                    yq eval \
                      ${lib.escapeShellArg preserveExpr} "$target" 2>/dev/null \
                      || true
                  } | grep -v '^#' > "$runtime_overlay" || true

                  if [ "$(yq eval 'length' "$runtime_overlay" 2>/dev/null || echo 0)" != "0" ]; then
                    if yq eval-all \
                      'select(fileIndex == 0) * select(fileIndex == 1)' \
                      "$src" "$runtime_overlay" > "$candidate" 2>/dev/null; then
                      :
                    else
                      install -m 644 "$src" "$candidate"
                    fi
                  fi
                  rm -f "$runtime_overlay"
                fi
              ''
          }

          if [ -f "$target" ] && cmp -s "$candidate" "$target"; then
            rm -f "$candidate"
            echo "moon-crab: SLSsteam config.yaml is up to date"
          else
            mv -f "$candidate" "$target"
            own "$target"
            echo "moon-crab: installed SLSsteam config.yaml to $target"
          fi
        '';

    assertions = [
      {
        assertion = target.user != null;
        message = ''
          programs.moon-crab.slssteam.settings is set, but no target user
          resolves (zero or several normal users). Set
          programs.moon-crab.user = "<name>";.
        '';
      }
    ];
  };
}
