{ inputs, ... }:
name: { system, modules ? [], home-modules ? [], machineConfig ? {} }:
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit inputs machineConfig; hostname = name; };
  modules = [
    ../hosts/common
    ../hosts/${name}
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = { inherit inputs; hostname = name; };
      home-manager.users.wowvain = {
        imports = [ ../home/common ] ++ home-modules;
      };
    }
  ] ++ modules;
}
