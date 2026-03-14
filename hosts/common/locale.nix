{ lib, ... }:
{
  time.timeZone = lib.mkDefault "Europe/Bucharest";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
}
