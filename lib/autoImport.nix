# lib/autoImport.nix
# Recursive auto-import: discovers NixOS modules by directory convention.
#
# Convention:
#   - Directory WITH default.nix    = module (import it, stop recursing)
#   - Directory WITHOUT default.nix = category folder (recurse into it)
#   - Ignores files, hidden dirs (. prefix), and underscore dirs (_ prefix)
#
# Signature: path -> [path]
#   Input:  absolute path to a directory (e.g., ../modules/system)
#   Output: list of paths to directories containing default.nix
#
# Example directory structure:
#   modules/system/
#     core/                    # no default.nix -> category, recurse
#       locale/                # has default.nix -> module, import
#         default.nix
#       users/                 # has default.nix -> module, import
#         default.nix
#     security/                # no default.nix -> category, recurse
#       firewall/              # has default.nix -> module, import
#         default.nix
#
# Result: [ .../core/locale  .../core/users  .../security/firewall ]
#
# Usage in mkHost.nix:
#   modules = (import ../lib/autoImport.nix ../modules/system)
#          ++ (import ../lib/autoImport.nix ../modules/user);

let
  autoImport = dir:
    let
      entries = builtins.readDir dir;

      # Filter to only directories, excluding hidden (.) and underscore (_) prefixed
      dirNames = builtins.filter
        (name:
          entries.${name} == "directory"
          && builtins.substring 0 1 name != "."
          && builtins.substring 0 1 name != "_")
        (builtins.attrNames entries);

      # For each subdirectory, check if it's a module or category
      processDir = name:
        let
          fullPath = dir + "/${name}";
        in
          if builtins.pathExists (fullPath + "/default.nix")
          then [ fullPath ]        # Module found -- return its path
          else autoImport fullPath; # Category folder -- recurse

    in builtins.concatMap processDir dirNames;

in autoImport
