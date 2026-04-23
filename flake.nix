{
  description = "BruvTab 2.0.1 browser tab control with Nix-friendly browser integration outputs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      chromeCrxHash = "sha256-FDpnX7pt2yDPg9JnMnM3307+QceFGDNjLHxLEd4X3fc=";
      chromeCrxVersion = "2.0.1";
      chromeExtensionId = "edpgjheobdplebiikjgjgpmonakingef";
      lib = nixpkgs.lib;
      signedFirefoxXpiVersion = "2.0.0";
      signedFirefoxXpiHash = "sha256-sx6JWSbaF4GTwHaKdkq33u7JSghPfVgeRmOihN2Bsp8=";
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
          signedFirefoxXpi = pkgs.fetchurl {
            url = "https://github.com/pschmitt/bruvtab/releases/download/${signedFirefoxXpiVersion}/469b5c80160a48cda84c-${signedFirefoxXpiVersion}.xpi";
            hash = signedFirefoxXpiHash;
          };
          chromeCrx = pkgs.runCommand "bruvtab-chrome-crx-${chromeCrxVersion}" { } ''
              mkdir -p $out
              cp ${chromeCrxAsset} $out/bruvtab.crx
              printf '%s' '${chromeExtensionId}' > $out/extension-id
            '';
          bruvtab = py.buildPythonApplication {
            pname = "bruvtab";
            version = "2.0.1";
            format = "pyproject";
            src = self;

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

              cp -R bruvtab/extension/chrome/. \
                $out/lib/bruvtab/extensions/chrome/
              cp -R bruvtab/extension/firefox/. \
                $out/lib/bruvtab/extensions/firefox/
            '';

            pythonImportsCheck = [
              "bruvtab"
            ];
          };

          chromeExtension = pkgs.runCommand "bruvtab-chrome-extension-2.0.1" { } ''
            mkdir -p $out
            cp -R ${self}/bruvtab/extension/chrome/. $out/
          '';

          firefoxAddon =
            pkgs.runCommand "bruvtab-firefox-addon-2.0.1"
              {
                passthru = {
                  addonId = "bruvtab_mediator@example.org";
                  extid = "bruvtab_mediator@example.org";
                };
              }
              ''
                addon_id='bruvtab_mediator@example.org'

                mkdir -p "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
                cp ${signedFirefoxXpi} "$out/$addon_id.xpi"

                ln -s "$out/$addon_id.xpi" \
                  "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/$addon_id.xpi"
              '';

          firefoxExtension = pkgs.runCommand "bruvtab-firefox-extension-2.0.1" { } ''
            mkdir -p $out
            cp -R ${self}/bruvtab/extension/firefox/. $out/
          '';
        in
        {
          default = bruvtab;
          bruvtab = bruvtab;
          chromeExtension = chromeExtension;
          chromeCrx = chromeCrx;
          firefoxAddon = firefoxAddon;
          firefoxExtension = firefoxExtension;
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
