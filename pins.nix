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
  rev = "2786a2a72088ecf32aea5b3ec52099e6a7cff78f";

  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    sha256 = "0fm3lxj743j3ksdhs31lb2sn9bkix3kvam2qb4hc8ipr2yzmbxbz";
  };
in
{
  inherit rev nixpkgs;

  # The pinned package set used by the modules that need newer packages.
  # claude-code and antigravity-cli are unfree; allow them for
  # programs.orca.agents.
  unstablePkgs = import nixpkgs {
    config.allowUnfreePredicate =
      pkg:
      builtins.elem (pkg.pname or "") [
        "claude-code"
        "antigravity-cli"
      ];
  };
}
