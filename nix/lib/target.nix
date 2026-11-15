# Resolves programs.moon-crab.user (or the auto-detected single normal user)
# to the user + home directory every user-scoped feature writes into.
{ config, lib }:
let
  normalUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser or false) config.users.users);
  detected = if lib.length normalUsers == 1 then lib.head normalUsers else null;
  user = if config.programs.moon-crab.user != null then config.programs.moon-crab.user else detected;
  home =
    if user != null && config.users.users ? ${user} then config.users.users.${user}.home else null;
in
{
  inherit user home;
}
