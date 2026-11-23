{
  ...
}:
{
  ai = {
    enable = true;

    # One-time move of the model store left behind by the old Home Manager
    # Ollama service. Remove this line after the first successful rebuild.
    ollama.legacyModelDir = "/home/timj/.ollama/models";
  };

  services.herdr = {
    enable = true;
    # Reachable via the Tailscale tailnet (tailscale is enabled above).
    tailnet.enable = true;
  };

  services.orca-ide = {
    enable = true;
    # Opens the Orca port on the tailnet for paired clients. The desktop app
    # keeps its own "Advertise this app as a server" toggle; services.orca-server
    # stays disabled so the two are not run together.
    tailnet.enable = true;
  };
}
