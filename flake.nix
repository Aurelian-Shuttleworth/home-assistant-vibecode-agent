{
  description = "Home Assistant Vibecode Agent Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonPackages = pkgs.python311Packages;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python311
            pythonPackages.fastapi
            pythonPackages.uvicorn
            pythonPackages.python-multipart
            pythonPackages.pydantic
            pythonPackages.pyyaml
            pythonPackages.aiohttp
            pythonPackages.aiofiles
            pythonPackages.python-dotenv
            pythonPackages.gitpython
            pythonPackages.requests
            pythonPackages.jinja2
            pythonPackages.pytest
          ];

          shellHook = ''
            echo "Home Assistant Vibecode Agent Dev Environment"
            echo "Python version: $(python --version)"
          '';
        };
      }
    );
}
