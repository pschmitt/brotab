{
  description = "BruvTab 2.0.1 browser tab control with Nix-friendly browser integration outputs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
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
          signedFirefoxXpi = pkgs.fetchurl {
            url = "https://github.com/pschmitt/bruvtab/releases/download/${signedFirefoxXpiVersion}/469b5c80160a48cda84c-${signedFirefoxXpiVersion}.xpi";
            hash = signedFirefoxXpiHash;
          };
          # Chrome CRX package; note that this generates a local keypair at build time.
          # Downstream consumers must use the generated extension-id file alongside the CRX.
          chromeCrx = pkgs.runCommand "bruvtab-chrome-crx-2.0.1"
            {
              nativeBuildInputs = [ pkgs.zip pkgs.openssl pkgs.python3 ];
            } ''
            mkdir -p $out
            cp -R ${self}/bruvtab/extension/chrome ./src
            chmod -R +w ./src

            # Strip existing key
            python3 -c "import json; d=json.load(open('src/manifest.json')); d.pop('key', None); json.dump(d, open('src/manifest.json', 'w'))"

            # Generate private key
            openssl genrsa -out key.pem 2048 2>/dev/null
            # Extract public key in DER format
            openssl rsa -in key.pem -pubout -outform DER -out pubkey.der 2>/dev/null

            # Create ZIP
            (cd src && zip -qr ../extension.zip .)

            # Sign the ZIP
            openssl dgst -sha256 -sign key.pem -out sig.bin extension.zip

            # Construct CRX v3 header and file using Python
            python3 - <<'PY'
import sys

def to_base128(n):
    res = bytearray()
    while n > 0x7f:
        res.append((n & 0x7f) | 0x80)
        n >>= 7
    res.append(n)
    return res

with open('pubkey.der', 'rb') as f: pubkey = f.read()
with open('sig.bin', 'rb') as f: sig = f.read()
with open('extension.zip', 'rb') as f: zip_data = f.read()

inner = b'\x0a' + to_base128(len(pubkey)) + pubkey + b'\x12' + to_base128(len(sig)) + sig
header = b'\x0a' + to_base128(len(inner)) + inner

with open('bruvtab.crx', 'wb') as f:
    f.write(b'Cr24')
    f.write(b'\x03\x00\x00\x00')
    f.write(len(header).to_bytes(4, 'little'))
    f.write(header)
    f.write(zip_data)
PY

            extension_id=$(openssl sha256 -binary pubkey.der | head -c 16 | \
              python3 -c "import sys; print('''.join([chr(ord('a') + (x >> 4)) + chr(ord('a') + (x & 0x0f)) for x in sys.stdin.buffer.read()]))")

            echo -n "$extension_id" > $out/extension-id
            cp bruvtab.crx $out/
            cp key.pem $out/
            echo "Generated Extension ID: $extension_id"
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

              chrome_ext_id="$(cat ${chromeCrx}/extension-id)"

              jq --arg out "$out" '.path = "\($out)/bin/bruvtab_mediator"' \
                bruvtab/mediator/firefox_mediator.json \
                > $out/lib/mozilla/native-messaging-hosts/bruvtab_mediator.json

              jq --arg out "$out" --arg ext "$chrome_ext_id" '
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
