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
         then import path
         else throw "Missing ${path} — copy local/${name}.nix.example to local/${name}.nix and fill in your values";
  in {
    nixosConfigurations = {
      server = mkHost "server" {
        system = "x86_64-linux";
        machineConfig = localConfig "server";
      };
      workstation = mkHost "workstation" {
        system = "x86_64-linux";
        home-modules = [ ./home/desktop ];
        machineConfig = localConfig "workstation";
      };
    };
  };
}
