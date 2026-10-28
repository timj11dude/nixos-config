{ unstablePkgs, ...}: {
  programs.opencode = {
    enable = true;
    package = unstablePkgs.opencode;
  };
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    environmentVariables = {
      SYNC_MODELS = "true";
      LOAD_MODELS = "mukunthpr/gemma4-e4b-code";
    };
  };
}
