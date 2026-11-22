# test-nixos-config

Run `./check.sh` at the project root to validate Nix configuration changes.

## Usage

Before rebuilding, invoke:

```
./check.sh
```

## Behaviour

1. Parses every `.nix` file in the project (excluding `.git`).
2. Evaluates the full system configuration via `nix-instantiate`.
3. Runs `nixfmt --check` on the AI/herdr modules.

The `--add-root` warning that may appear in the output can be safely ignored; it does not indicate a failure. Only treat a non-zero exit code from `./check.sh` as a failure.

## Example

```
./check.sh
==> Parsing Nix files
==> Evaluating the system configuration
==> Checking formatting of the AI module
OK
```
