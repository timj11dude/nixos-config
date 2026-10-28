# Pinned package sources.
#
# Previously the unstable packages came from the local <nixos-unstable>
# channel, so updating the channel (or the system auto-upgrade) could silently
# change OpenCode/Ollama/Jujutsu without a commit. Update a pin with:
#
#   nix-prefetch-url --unpack https://github.com/NixOS/nixpkgs/archive/<rev>.tar.gz
#
# then bump `rev` and `sha256` below.
let
  rev = "31ecbaca1bdefa45dffc409f0250bd8039ea0010";

  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    sha256 = "1lzqyss0pznfh3az0llsp4a7c8gqcyq8wf96fnl5cnh5b3lic6kn";
  };
in
{
  inherit rev nixpkgs;

  # The pinned package set used by the modules that need newer packages.
  unstablePkgs = import nixpkgs { };
}
