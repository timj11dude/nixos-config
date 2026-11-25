{
  pkgs,
  unstablePkgs,
  secretspecFile,
}:
pkgs.writeShellApplication {
  name = "with-gpg";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.gnupg
    unstablePkgs.bws
    unstablePkgs.secretspec
  ];
  text = ''
    export SECRETSPEC_FILE="''${SECRETSPEC_FILE:-${secretspecFile}}"
    export SECRETSPEC_PROFILE="''${SECRETSPEC_PROFILE:-gpg}"

    if [ -z "''${GPG_PRIVATE_KEY:-}" ]; then
      exec secretspec run -- "$0" "$@"
    fi

    if [ -z "''${XDG_RUNTIME_DIR:-}" ] || [ ! -d "$XDG_RUNTIME_DIR" ]; then
      echo "with-gpg: XDG_RUNTIME_DIR is not set or does not exist" >&2
      exit 1
    fi

    gpg_home="$(mktemp -d "''${XDG_RUNTIME_DIR}/gnupg-ephemeral.XXXXXX")"
    chmod 700 "$gpg_home"

    cleanup() {
      GNUPGHOME="$gpg_home" gpgconf --kill gpg-agent >/dev/null 2>&1 || true
      rm -rf "$gpg_home"
    }
    trap cleanup EXIT INT TERM

    cat > "''${gpg_home}/gpg-agent.conf" <<EOF
    enable-ssh-support
    pinentry-program ${pkgs.pinentry-qt}/bin/pinentry-qt
    EOF

    export GNUPGHOME="$gpg_home"
    printf '%s\n' "$GPG_PRIVATE_KEY" | gpg --batch --quiet --import
    if [ -n "''${GPG_OWNERTRUST:-}" ]; then
      printf '%s\n' "$GPG_OWNERTRUST" | gpg --batch --quiet --import-ownertrust
    fi
    unset GPG_PRIVATE_KEY GPG_OWNERTRUST SOPS_AGE_KEY RESTIC_PASSWORD

    # Authorize any imported secret key/subkey with authentication ('a') capability for SSH
    gpg --batch --with-colons --with-keygrip --list-secret-keys \
      | awk -F: '
          $1 == "sec" || $1 == "ssb" { want = (index($12, "a") > 0) }
          $1 == "grp" && want { print $10; want = 0 }
        ' > "''${gpg_home}/sshcontrol"

    # Restart gpg-agent in case `gpg --import` auto-started it before sshcontrol existed
    gpgconf --kill gpg-agent >/dev/null 2>&1 || true
    gpgconf --launch gpg-agent
    SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
    export SSH_AUTH_SOCK

    if [ "$#" -eq 0 ]; then
      "''${SHELL:-/bin/sh}"
    else
      "$@"
    fi
  '';
}
