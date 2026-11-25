{
  lib,
  osConfig,
  ...
}:
let
  # Effective context window served by Ollama. Mirrors
  # ai.ollama.contextLength in the system module so consumers plan against the
  # real limit instead of a models.dev default the server never honours.
  contextLength = osConfig.ai.ollama.contextLength or 16384;
in
{
  options.ai = {
    contextLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = contextLength;
      defaultText = lib.literalExpression "osConfig.ai.ollama.contextLength or 16384";
      description = ''
        Effective context window served by the local Ollama instance.
      '';
    };

    # Only models that the local Ollama server actually serves. Keep this in
    # sync with ai.ollama.models in the system module.
    models = lib.mkOption {
      type = lib.types.attrs;
      default = {
        "llama3.2:latest" = {
          name = "Llama 3.2 (3.2B)";
          limit = {
            context = contextLength;
            output = 4096;
          };
        };
        "qwen2.5-coder:7b" = {
          name = "Qwen 2.5 Coder (7B)";
          limit = {
            context = contextLength;
            output = 4096;
          };
        };
        "devstral:latest" = {
          name = "Devstral (23.6B, coding)";
          limit = {
            context = contextLength;
            output = 4096;
          };
        };
        "JetBrains/Mellum-4b-base:latest" = {
          name = "Mellum 4B (base)";
          tool_call = false;
          # Base completion model trained on an 8k window.
          limit = {
            context = 8192;
            output = 4096;
          };
        };
      };
      description = "Ollama model definitions shared by AI consumers.";
    };
  };
}
