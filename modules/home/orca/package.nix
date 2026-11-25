{
  lib,
  stdenvNoCC,
  fetchurl,
  bintools,
  autoPatchelfHook,
  makeWrapper,
  gobject-introspection,
  wrapGAppsHook3,
  copyDesktopItems,
  makeDesktopItem,
  python3,
  versionCheckHook,

  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gcc-unwrapped,
  glib,
  gtk3,
  libX11,
  libxcb,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxkbcommon,
  libgbm,
  nspr,
  nss,
  pango,
  systemdLibs,

  libglvnd,
  libsecret,
  libnotify,
  libpulseaudio,
  libayatana-appindicator,
  libXcursor,
  pipewire,
  wayland,

  # Orca (GitHub integration, `orca serve`, and computer-use) shells out to these.
  gh,
  git,
  coreutils,
  openssh,
  which,
  wl-clipboard,
  xclip,
  xdotool,
  xdg-utils,
  xvfb-run,

  # Agent CLIs Orca drives (e.g. Claude Code, Antigravity CLI). Appended to the
  # wrapper PATH so `orca serve` can spawn them from a bare systemd
  # environment; anything earlier on the user's PATH still wins.
  agentTools ? [ ],

  adwaita-icon-theme,
  gsettings-desktop-schemas,
}:

let
  version = "1.4.271";

  # Hashes from upstream packages/orca/hashes.json (llm-agents.nix).
  sources = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-f609ch3AsJIPJINT9Tkf4BODMXkay2TJZ3x6kb9B51U=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-LK7TTW9usS4mV4fayv/tUNw5dGdPi674m142c3CqdwY=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "orca-ide: unsupported system ${stdenvNoCC.hostPlatform.system}");

  computerUsePython = python3.withPackages (ps: [ ps.pygobject3 ]);

  runtimeTools = [
    coreutils
    gh
    git
    # Antigravity native-chat auth probes the Linux keyring via gdbus + secret-tool.
    glib.bin
    libsecret
    openssh
    python3
    which
    wl-clipboard
    xclip
    xdg-utils
    xdotool
    xvfb-run
  ];

  desktopItem = makeDesktopItem {
    name = "orca-ide";
    desktopName = "Orca";
    genericName = "Agentic Development Environment";
    comment = "Next-gen IDE for parallel agentic development";
    exec = "orca-ide %U";
    icon = "orca-ide";
    categories = [ "Development" ];
    # Electron reports WM_CLASS=orca even though the executable is orca-ide,
    # so docks only group the window with this exact value.
    startupWMClass = "orca";
    mimeTypes = [
      "text/markdown"
      "text/csv"
      "text/tab-separated-values"
      "x-scheme-handler/orca"
    ];
  };
in
stdenvNoCC.mkDerivation {
  pname = "orca-ide";
  inherit version;

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-ide_${version}_${source.arch}.deb";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
    gobject-introspection
    wrapGAppsHook3
  ];

  buildInputs = [
    adwaita-icon-theme
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gcc-unwrapped.lib
    glib
    gsettings-desktop-schemas
    gtk3
    libgbm
    libX11
    libxcb
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxkbcommon
    nspr
    nss
    pango
    systemdLibs
  ];

  # dlopen()ed at runtime, so not discoverable from DT_NEEDED.
  runtimeDependencies = [
    gtk3
    libayatana-appindicator
    libnotify
    libpulseaudio
    libsecret
    libXcursor
    pipewire
    wayland
  ];

  desktopItems = [ desktopItem ];

  unpackPhase = ''
    runHook preUnpack
    ${lib.getExe' bintools "ar"} x $src
    tar xf data.tar.*
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Keep the upstream opt/Orca layout so the bundled libs (libffmpeg.so),
    # resources/, and app.asar.unpacked all resolve relative to the binary.
    mkdir -p $out/lib $out/bin $out/share
    cp -a opt/Orca $out/lib/Orca
    cp -a usr/share/icons $out/share/icons

    # chrome-sandbox needs setuid root, which a store path can never have.
    # Electron falls back to user namespaces.
    rm -f $out/lib/Orca/chrome-sandbox

    rm -rf $out/lib/Orca/resources/node_modules/@koromix/koffi-linux-*/musl_*

    chmod +x $out/lib/Orca/orca-ide $out/lib/Orca/resources/bin/orca-ide

    mkdir -p "$out/libexec"
    cat > "$out/libexec/orca-computer-use.py" <<EOF
    import os
    import sys
    os.execv("$out/libexec/orca-computer-use-python", ["$out/libexec/orca-computer-use-python", *sys.argv[1:]])
    EOF

    runHook postInstall
  '';

  dontWrapGApps = true;
  # orcad-template/targets holds per-platform daemon builds that Orca uploads to
  # remote hosts and verifies by sha256, so they must stay unpatched and unstripped.
  dontStrip = true;
  dontAutoPatchelf = true;
  postFixup = ''
    autoPatchelf \
      $(find "$out/lib/Orca" -mindepth 1 -maxdepth 1 ! -name resources) \
      $(find "$out/lib/Orca/resources" -mindepth 1 -maxdepth 1 ! -name orcad-template)

    makeWrapper "${lib.getExe computerUsePython}" "$out/libexec/orca-computer-use-python" \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "$out/lib/Orca/resources/computer-use-linux/runtime.py"

    # The launcher and the bundled CLI share one environment so `orca serve`
    # and the desktop app see the same tools.
    launcherArgs=(
      "''${gappsWrapperArgs[@]}"
      --prefix XDG_DATA_DIRS : "$XDG_ICON_DIRS"
      --set-default ORCA_COMPUTER_DESKTOP_SCRIPT_PROVIDER_PATH "$out/libexec/orca-computer-use.py"
      --suffix PATH : "${lib.makeBinPath (runtimeTools ++ agentTools)}"
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libglvnd ]}"
    )
    makeWrapper "$out/lib/Orca/orca-ide" "$out/bin/orca-ide" "''${launcherArgs[@]}"
    wrapProgram "$out/lib/Orca/resources/bin/orca-ide" "''${launcherArgs[@]}"
    ln -s "$out/lib/Orca/resources/bin/orca-ide" "$out/bin/orca"

    # Point the desktop entry at the wrapped GUI binary in $out/bin so user
    # PATH shims (e.g. ~/.local/bin/orca-ide) cannot shadow it with the CLI.
    substituteInPlace "$out/share/applications/orca-ide.desktop" \
      --replace-fail "Exec=orca-ide %U" "Exec=$out/bin/orca-ide %U"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/orca";
  preVersionCheck = ''
    export HOME=$TMPDIR
  '';
  postInstallCheck = ''
    makeWrapper "${lib.getExe computerUsePython}" "$TMPDIR/check-computer-use-python" \
      "''${gappsWrapperArgs[@]}"
    "$TMPDIR/check-computer-use-python" -c '
    import gi
    gi.require_version("Atspi", "2.0")
    gi.require_version("Gdk", "3.0")
    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import Atspi, Gdk, GdkPixbuf
    '
  '';

  meta = with lib; {
    description = "ADE for working with a fleet of parallel coding agents";
    homepage = "https://orca.dev";
    changelog = "https://github.com/stablyai/orca/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "orca-ide";
    platforms = builtins.attrNames sources;
  };
}
