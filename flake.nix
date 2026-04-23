{
  description = "BruvTab 2.0 browser tab control with Nix-friendly browser integration outputs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
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
          bruvtab = py.buildPythonApplication rec {
            pname = "bruvtab";
            version = "2.0.0";
            format = "setuptools";
            src = self;

            nativeBuildInputs = [
              pkgs.jq
            ];

            propagatedBuildInputs = with py; [
              flask
              psutil
              requests
              setuptools
              werkzeug
            ];

            nativeCheckInputs = with py; [
              pytestCheckHook
            ];

            postInstall = ''
              mkdir -p $out/lib/mozilla/native-messaging-hosts $out/lib/chromium/NativeMessagingHosts
              mkdir -p $out/lib/bruvtab/extensions/chrome $out/lib/bruvtab/extensions/firefox

              jq --arg out "$out" '.path = "\($out)/bin/bruvtab_mediator"' \
                bruvtab/mediator/firefox_mediator.json \
                > $out/lib/mozilla/native-messaging-hosts/bruvtab_mediator.json

              jq --arg out "$out" --arg ext "knldjmfmopnpolahpmmgbagdohdnhkik" '
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

          chromeExtension = pkgs.runCommand "bruvtab-chrome-extension-2.0.0" { } ''
            mkdir -p $out
            cp -R ${self}/bruvtab/extension/chrome/. $out/
          '';

          firefoxAddon =
            pkgs.runCommand "bruvtab-firefox-addon-2.0.0"
              {
                passthru = {
                  addonId = "bruvtab_mediator@example.org";
                  extid = "bruvtab_mediator@example.org";
                };
              }
              ''
                addon_id='bruvtab_mediator@example.org'

                mkdir -p "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
                cp ${self}/artifacts/firefox/bruvtab_mediator@example.org.xpi "$out/$addon_id.xpi"

                ln -s "$out/$addon_id.xpi" \
                  "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/$addon_id.xpi"
              '';

          firefoxExtension = pkgs.runCommand "bruvtab-firefox-extension-2.0.0" { } ''
            mkdir -p $out
            cp -R ${self}/bruvtab/extension/firefox/. $out/
          '';
        in
        {
          default = bruvtab;
          bruvtab = bruvtab;
          chromeExtension = chromeExtension;
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
            ps.flask
            ps.psutil
            ps.pytest
            ps.requests
            ps.setuptools
            ps.werkzeug
          ]);
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.jq
              pkgs.nodejs
              pkgs.web-ext
              py
            ];
          };
        });
    };
}
