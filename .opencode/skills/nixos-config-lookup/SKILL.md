---
name: nixos-config-lookup
description: Use when looking up resources or options for configuring NixOS or Home Manager. Use the dedicated links for documentation lookup.
---

# NixOS/HomeManager Resource Lookup

This skill provides centralized access points for looking up official documentation and options for NixOS and Home Manager.

## NixOS Packages Search
For comprehensive package listings and resource lookups for NixOS, use the official search page:
*   **URL:** <https://search.nixos.org/packages>
*   **Use Case:** Discovering available packages, viewing dependencies, and understanding package options.

## Home Manager Options
For checking specific options and values available for Home Manager configurations, use the dedicated options browser:
*   **URL:** <https://home-manager-options.extranix.com/>
*   **Use Case:** Validating attribute set keys and their allowed values for `home.nix` or `nixpkgs` usage.

### Workflow

When a user asks about configuring a specific NixOS or Home Manager option, I should recommend using one of these two links.

**Example Prompts:**
- "What is the best way to configure `pkgs.gdm` in NixOS?"
- "How do I enable automatic background sync for Home Manager?"

**Note:** These links point to external documentation sites and are not processed by the internal knowledge base, so manual verification is required.