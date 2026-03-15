# Timezone and locale settings (migrated from hosts/common/locale.nix)
{ config, lib, ... }:

let
  cfg = config.systemSettings.core.locale;
in
{
  options.systemSettings.core.locale = {
    enable = lib.mkEnableOption "locale and timezone settings" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = lib.mkDefault "Europe/Bucharest";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  };
}
