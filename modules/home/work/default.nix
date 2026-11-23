{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    dotnet-sdk
    jetbrains.idea
    jetbrains.rider
    super-productivity
    terraform
  ];

  programs.firefox.profiles.timj.containers.work = {
    name = "Work";
    color = "orange";
    icon = "briefcase";
    id = 2;
  };

  nixpkgs.config.allowUnfreePackages = [
    "idea"
    "rider"
    "terraform"
  ];
}
