.PHONY: switch-server switch-workstation boot-server check update

-include local/deploy.env

switch-server:
	nixos-rebuild switch --flake .#server --impure \
		--target-host $(SERVER_SSH) \
		--build-host localhost

switch-workstation:
	sudo nixos-rebuild switch --flake .#workstation --impure

boot-server:
	nixos-rebuild boot --flake .#server --impure \
		--target-host $(SERVER_SSH) \
		--build-host localhost

check:
	nix flake check

update:
	nix flake update
