{
  description = "BruvTab browser tab control with Nix-friendly browser integration outputs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      version = "2.0.6";
      chromeCrxVersion = version;
      chromeCrxHash = "sha256-BDpyzpgy4NS8X9gg/U4HGheHG+44tZbpQYNwRs5lPEw=";
      firefoxXpiVersion = version;
      firefoxXpiHash = "sha256-lx9H5IlwDgVJP6imVxdiGqKRRFxRfbSsbVmTr2tSeZ8=";
      chromeExtensionId = "edpgjheobdplebiikjgjgpmonakingef";
      firefoxAddonId = "bruvtab_mediator@example.org";
      firefoxAppId = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";
      lib = nixpkgs.lib;
      projectSource = lib.cleanSourceWith {
        src = self;
        filter =
          path: type:
          let
            base = baseNameOf path;
          in
          !(builtins.elem base [
            ".git"
            ".pytest_cache"
            ".venv"
            "bruvtab.egg-info"
            "build"
            "dist"
          ])
          && !(lib.hasSuffix ".pem" base);
      };
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          py = pkgs.python3Packages;
          chromeCrxAsset = pkgs.fetchurl {
            url = "https://github.com/pschmitt/bruvtab/releases/download/${chromeCrxVersion}/bruvtab-chrome-${chromeCrxVersion}.crx";
            hash = chromeCrxHash;
          };
          firefoxXpiAsset = pkgs.fetchurl {
            url = "https://github.com/pschmitt/bruvtab/releases/download/${firefoxXpiVersion}/bruvtab-firefox-${firefoxXpiVersion}.xpi";
            hash = firefoxXpiHash;
          };
          chromeCrx = pkgs.runCommand "bruvtab-chrome-crx-${chromeCrxVersion}" { } ''
              mkdir -p $out
              cp ${chromeCrxAsset} $out/bruvtab.crx
              printf '%s' '${chromeExtensionId}' > $out/extension-id
            '';
          bruvtab = py.buildPythonApplication {
            pname = "bruvtab";
            inherit version;
            format = "pyproject";
            src = projectSource;

            nativeBuildInputs = with py; [
              pkgs.jq
              setuptools
              wheel
            ];

            propagatedBuildInputs = with py; [
              flask
              psutil
              requests
              rich
              rich-argparse
              werkzeug
            ];

            nativeCheckInputs = with py; [
              pytestCheckHook
              pytest-cov
            ];

            postInstall = ''
              mkdir -p $out/lib/mozilla/native-messaging-hosts $out/lib/chromium/NativeMessagingHosts
              mkdir -p $out/etc/chromium/native-messaging-hosts
              mkdir -p $out/lib/bruvtab/extensions/chrome $out/lib/bruvtab/extensions/firefox

              jq --arg out "$out" '.path = "\($out)/bin/bruvtab_mediator"' \
                bruvtab/mediator/firefox_mediator.json \
                > $out/lib/mozilla/native-messaging-hosts/bruvtab_mediator.json

              jq --arg out "$out" --arg ext "${chromeExtensionId}" '
                .path = "\($out)/bin/bruvtab_mediator"
                | .allowed_origins = (
                    (.allowed_origins // [])
                    + ["chrome-extension://\($ext)/"]
                  | unique)
              ' \
                bruvtab/mediator/chromium_mediator.json \
                > $out/lib/chromium/NativeMessagingHosts/bruvtab_mediator.json

              cp \
                $out/lib/chromium/NativeMessagingHosts/bruvtab_mediator.json \
                $out/etc/chromium/native-messaging-hosts/bruvtab_mediator.json

              cp -R bruvtab/extension/chrome/. \
                $out/lib/bruvtab/extensions/chrome/
              cp -R bruvtab/extension/firefox/. \
                $out/lib/bruvtab/extensions/firefox/
            '';

            pythonImportsCheck = [
              "bruvtab"
            ];
          };

          firefoxXpi =
            pkgs.runCommand "bruvtab-firefox-xpi-${version}"
              {
                passthru = {
                  addonId = firefoxAddonId;
                  extid = firefoxAddonId;
                };
              }
              ''
                addon_id='${firefoxAddonId}'

                mkdir -p "$out/share/mozilla/extensions/${firefoxAppId}"
                cp ${firefoxXpiAsset} "$out/$addon_id.xpi"

                ln -s "$out/$addon_id.xpi" \
                  "$out/share/mozilla/extensions/${firefoxAppId}/$addon_id.xpi"
              '';

        in
        {
          default = bruvtab;
          bruvtab = bruvtab;
          chromeCrx = chromeCrx;
          firefoxAddon = firefoxXpi;
          firefoxXpi = firefoxXpi;
        });

      apps = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          pkg = self.packages.${system}.default;
        in
        {
          default = {
            type = "app";
            program = "${pkg}/bin/bruvtab";
          };
          bruvtab = {
            type = "app";
            program = "${pkg}/bin/bruvtab";
          };
          sign-firefox-addon = {
            type = "app";
            program = "${pkgs.writeShellApplication {
              name = "sign-firefox-addon";
              runtimeInputs = [
                pkgs.git
                pkgs.web-ext
              ];
              text = ''
                exec "${self}/scripts/sign-firefox-addon.sh" "$@"
              '';
            }}/bin/sign-firefox-addon";
          };
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          py = pkgs.python3.withPackages (ps: [
            ps.build
            ps.flask
            ps.psutil
            ps.pytest
            ps.pytest-cov
            ps.requests
            ps.rich
            ps.rich-argparse
            ps.werkzeug
          ]);
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.docker
              pkgs.git
              pkgs.go-crx3
              pkgs.jq
              pkgs.just
              pkgs.nodejs
              pkgs.openssl
              pkgs.web-ext
              pkgs.zip
              py
            ];
          };
        });
    };
}
