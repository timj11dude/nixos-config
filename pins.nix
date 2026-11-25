# Pinned external sources.
#
# Centralizes every non-channel dependency so updating a pin happens in one
# place and all NixOS / Home Manager modules share a single evaluation (passed
# via `_module.args` and `home-manager.extraSpecialArgs`).
#
# Update a GitHub tarball pin with:
#   nix-prefetch-url --unpack https://github.com/<owner>/<repo>/archive/<ref>.tar.gz
# then bump the ref/rev and sha256 below.
let
  nixpkgsRev = "2786a2a72088ecf32aea5b3ec52099e6a7cff78f";

  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsRev}.tar.gz";
    sha256 = "0fm3lxj743j3ksdhs31lb2sn9bkix3kvam2qb4hc8ipr2yzmbxbz";
  };

  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz";
    sha256 = "0x0dcasjli38yabl1dpq4ymg7ixv02hd825676irw5cir8z0r2jx";
  };

  disko = builtins.fetchTarball {
    url = "https://github.com/nix-community/disko/archive/master.tar.gz";
    sha256 = "1f2wsz31rf4sqg7spsjnq82c97gicn8zxlnj2zjsmm5g1pcnfzhg";
  };

  sops-nix = builtins.fetchTarball {
    url = "https://github.com/Mic92/sops-nix/archive/cff8437c5fe8c68fc3a840a21bf1f4dc801da40d.tar.gz";
    sha256 = "1ddxjbwlygzcylvmj1vbgwv2hl0vwh911wsxk21qmwmlhq8pbgfr";
  };

  noctaliaRev = "v5.4.1";
  noctalia = {
    rev = noctaliaRev;
    src = builtins.fetchTarball {
      url = "https://github.com/noctalia-dev/noctalia/archive/refs/tags/${noctaliaRev}.tar.gz";
      sha256 = "0ih3aizacgi1v5b5qq907p3j6vsx0wjvnf9hc9gqwasb1dqir8cg";
    };
  };
in
{
  rev = nixpkgsRev;
  inherit
    nixpkgs
    home-manager
    disko
    sops-nix
    noctalia
    ;

  # The pinned unstable package set used by modules that need newer packages.
  # claude-code and antigravity-cli are unfree; allow them for
  # programs.orca.agents / services.orca-server.agents.
  unstablePkgs = import nixpkgs {
    config.allowUnfreePredicate =
      pkg:
      builtins.elem (pkg.pname or "") [
        "antigravity-cli"
        "bws"
        "claude-code"
      ];
  };
}
