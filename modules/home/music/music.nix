{ config, pkgs, osConfig, ... }:
{
  #todo need to add configuration to change audio driver used
  programs.spotify-player = {
    enable = true;
    settings = let
      default = fromTOML (builtins.readFile ./app.toml); # generated when not overridden by this settings block
     in default // {
      enable_audio_visualization = true;
    };
    #    package = (pkgs.spotify-player.override { withAudioBackend = "pulseaudio"; });
  };
}
