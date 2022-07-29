{
  description = "Temporal Entity";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {system = system;};
      gems = pkgs.bundlerEnv {
        name = "temporal-entity-env-1";
        gemdir = ./.;
      };
    in {
      devShell = pkgs.mkShell {
        buildInputs = [
          gems
          gems.ruby
           pkgs.postgresql
           pkgs.mysql
        ];
      };
    });
}
