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
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, ... }@inputs:
  let
    mkHost = import ./lib/mkHost.nix { inherit inputs; };
  in {
    nixosConfigurations = {
      server = mkHost "server" {
        system = "x86_64-linux";
      };
      workstation = mkHost "workstation" {
        system = "x86_64-linux";
        home-modules = [ ./home/desktop ];
      };
    };
  };
}
