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
}
