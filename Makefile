.PHONY: switch-server switch-workstation boot-server check update

switch-server:
	nixos-rebuild switch --flake .#server \
		--target-host root@46.224.225.195 \
		--build-host localhost

switch-workstation:
	sudo nixos-rebuild switch --flake .#workstation

boot-server:
	nixos-rebuild boot --flake .#server \
		--target-host root@46.224.225.195 \
		--build-host localhost

check:
	nix flake check

update:
	nix flake update
