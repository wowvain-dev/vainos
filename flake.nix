{
  description = "Vainos - unified NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vainim = {
      url = "github:wowvain-dev/vainim";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, vainim, ... }@inputs:
  let
    mkHost = import ./lib/mkHost.nix { inherit inputs; };

    # Machine-specific config loaded from local/ (requires --impure)
    # Uses absolute path via /etc/nixos symlink so gitignored files are visible
    localConfig = name:
      let
        root = let env = builtins.getEnv "VAINOS_ROOT";
               in if env != "" then env else "/etc/nixos";
        path = "${root}/local/${name}.nix";
      in if builtins.pathExists path
         then path   # Return PATH, not import result -- mkHost imports it as a NixOS module
         else throw "Missing ${path} -- copy local/${name}.nix.example to local/${name}.nix and fill in your values";

    # ---- Dynamic host scanner ----
    # Discovers hosts from hosts/ directory structure.
    # Convention: hosts/{name}/default.nix with systemSettings.system = host entry.
    # Excludes "common" (shared base config, not a host).
    hostEntries = builtins.readDir ./hosts;
    hostNames = builtins.filter
      (name: hostEntries.${name} == "directory"
             && name != "common"
             && builtins.pathExists (./hosts + "/${name}/default.nix"))
      (builtins.attrNames hostEntries);

    # Read systemSettings.system from host default.nix (per user decision).
    # The host default.nix is a NixOS module function { ... }: { ... }.
    # Calling it with {} returns the raw config attrset before NixOS processes it.
    # We read .systemSettings.system from that raw attrset.
    # IMPORTANT: This works because default.nix is now pure data -- no imports
    # block, no config blocks, just systemSettings/userSettings assignments.
    hostMeta = name:
      let
        raw = import (./hosts + "/${name}/default.nix") {};
      in {
        system = raw.systemSettings.system;
      };

    # Transitional: home-modules mapping.
    # Phase 5 migrates home/desktop/* into modules/user/desktop/ (auto-imported),
    # eliminating this lookup entirely.
    hostHomeModules = {
      workstation = [ ./home/desktop ];
    };

    mkHostConfig = name:
      let
        meta = hostMeta name;
      in {
        inherit name;
        value = mkHost name {
          system = meta.system;
          localConfigModule = localConfig name;
          home-modules = hostHomeModules.${name} or [];
        };
      };
  in {
    nixosConfigurations = builtins.listToAttrs (map mkHostConfig hostNames);
  };
}
