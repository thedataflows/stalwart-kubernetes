#!/bin/env bash

set -e -o pipefail -u

OS=${OS:-$(uname -s)}
STALWART_BASE=${STALWART_BASE:-/opt/stalwart-mail}

cd "${0%/*}"

if ! type ./stalwart-install &>/dev/null; then
  TAG=${TAG:-$(curl -s https://api.github.com/repos/stalwartlabs/mail-server/releases/latest | yq -r '.tag_name')}
  case $OS in
    Linux)
      set -x
      curl -L "https://github.com/stalwartlabs/mail-server/releases/download/$TAG/stalwart-install-x86_64-unknown-linux-gnu.tar.gz" | tar -xzvf -
      { set +x; } 2>/dev/null
      ;;
    Darwin)
      set -x
      curl -L "https://github.com/stalwartlabs/mail-server/releases/download/$TAG/stalwart-install-x86_64-apple-darwin.tar.gz" | tar -xzvf -
      { set +x; } 2>/dev/null
      ;;
    MINGW* | MSYS* | CYGWIN* | Windows_NT)
      temp_file=$(mktemp)
      set -x
      curl -L "https://github.com/stalwartlabs/mail-server/releases/download/$TAG/stalwart-install-x86_64-pc-windows-msvc.zip" -o "$temp_file"
      unzip -o "$temp_file"
      rm -fr "$temp_file"
      { set +x; } 2>/dev/null
      ;;
    *)
      echo "Unsupported OS: $OS"
      exit 1
      ;;
  esac
fi

CONFIG_DIR=config
STALWART_CONFIG_DIR="$CONFIG_DIR/etc"

set -x
## Cleanup
rm -fr "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

## Run installer
./stalwart-install -c all-in-one -p "$STALWART_CONFIG_DIR/.." -d
## Fix paths in toml files
sed -i -E "s,$STALWART_CONFIG_DIR/\.\.,$STALWART_BASE," "$STALWART_CONFIG_DIR/config.toml" "$STALWART_CONFIG_DIR/common/tls.toml"
## Enable stdoud logging
sed -i -E -e 's,^([^#]),#\1,g' -e '5,8s/^#//' "$STALWART_CONFIG_DIR/common/tracing.toml"

cp examples/litestream.yaml examples/statefulset.patch.yaml "$CONFIG_DIR"

## Cleanup
rm -fr \
    "${CONFIG_DIR:?}/bin" \
    "${CONFIG_DIR:?}/logs" \
    "${CONFIG_DIR:?}/queue" \
    "${CONFIG_DIR:?}/reports" \
    "$STALWART_CONFIG_DIR/spamfilter/" \
    "$STALWART_CONFIG_DIR/certs/" \
    "$STALWART_CONFIG_DIR/directory/ldap.toml" \
    "$STALWART_CONFIG_DIR/directory/memory.toml"
{ set +x; } 2>/dev/null

DKIM_FILES=$(
  cd "$CONFIG_DIR";
  set -x;
  find "etc/dkim" -type f -printf '      - %f=%p\n'
)
export DKIM_FILES

CONFIG_FILES=$(
  cd "$CONFIG_DIR";
  set -x;
  find etc -name '*.toml' -printf '      - %P=%p\n' | sed -E 's,/([^=]+)=,_\1=,'
)
export CONFIG_FILES

echo "apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

secretGenerator:
  - name: dkim
    type: Opaque
    options:
      disableNameSuffixHash: true
    files:
$DKIM_FILES

configMapGenerator:
  - name: litestream
    # options:
    #   disableNameSuffixHash: true
    files:
      - litestream.yml=litestream.yaml
  - name: stalwart
    # options:
    #   disableNameSuffixHash: true
    files:
$CONFIG_FILES" > "$CONFIG_DIR/kustomization.yaml"

## Generate volumeMounts patch
echo "$CONFIG_FILES" | yq '.[] |
  [
    {
      "op":"add",
      "path":"/spec/template/spec/containers/0/volumeMounts/-",
      "value":
        {
          "name":"config",
          "mountPath":"'$STALWART_BASE'/etc/"+(. | split("=").1),
          "subPath":. | split("=").0
        }
    }
  ]' > "$CONFIG_DIR/volume-mounts.patch.yaml"

## Generate ingress patch
STALWART_HOST=$(grep -E '^host' "$STALWART_CONFIG_DIR/config.toml" | cut -d\" -f2)
export STALWART_HOST
yq '.[0].value = env(STALWART_HOST)' examples/ingress.patch.yaml > "$CONFIG_DIR/ingress.patch.yaml"
