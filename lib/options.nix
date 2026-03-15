# lib/options.nix
# Core option namespace declarations for the vainos module framework.
#
# Declares two top-level option namespaces:
#   - systemSettings: system-level config (services, networking, boot, security)
#   - userSettings:   user-level config (editor, shell, browser, theme)
#
# Both use freeform submodules — any key is allowed without pre-declaration,
# but individual modules can declare typed sub-options within these namespaces
# (e.g., options.systemSettings.networking.serverIP = lib.mkOption { ... }).
#
# Usage in host configs (pure data):
#   systemSettings.system = "x86_64-linux";
#   systemSettings.networking.serverIP = "1.2.3.4";
#   userSettings.editor.defaultEditor = "nvim";
#
# Both namespaces are visible to all modules — system modules may need
# userSettings for user-specific paths, and user modules may need
# systemSettings for system state.

{ lib, ... }:
{
  options.systemSettings = lib.mkOption {
    type = with lib.types; submodule {
      freeformType = attrs;
    };
    default = {};
    description = ''
      System-level settings namespace.
      Services, networking, boot, security, hardware.
      Set by hosts, consumed by modules/system/.

      systemSettings.system (string, required) — architecture string
      (e.g., "x86_64-linux") used by the host scanner to determine
      the target platform.
    '';
  };

  options.userSettings = lib.mkOption {
    type = with lib.types; submodule {
      freeformType = attrs;
    };
    default = {};
    description = ''
      User-level settings namespace.
      Editor, shell, browser, theme, desktop preferences.
      Set by hosts, consumed by modules/user/.
    '';
  };
}
