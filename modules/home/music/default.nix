{
  config,
  lib,
  ...
}:
let
  cfg = config.my.music;
in
{
  options.my.music = {
    enable = lib.mkEnableOption "terminal Spotify client (spotify-player)";
  };

  config = lib.mkIf cfg.enable {
    # TODO: add configuration to select audio driver if needed
    programs.spotify-player = {
      enable = true;
      settings =
        let
          default = fromTOML (builtins.readFile ./app.toml); # generated when not overridden by this settings block
        in
        default
        // {
          enable_audio_visualization = true;
        };
    };
  };
}
