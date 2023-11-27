#!/bin/env bash

set -e

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

set -x
## Cleanup
rm -fr "$STALWART_BASE" common directory dkim imap jmap smtp
## Run installer
./stalwart-install -c all-in-one -p "$STALWART_BASE" -d
cp -fr "$STALWART_BASE"/etc/* .
{ set +x; } 2>/dev/null
## Fix path if installer was ran on a Windows host
case $OS in
MINGW* | MSYS* | CYGWIN* | Windows_NT)
  set -x
  sed -i -E "s,(^base_path\s*=\s*\").+,\1$STALWART_BASE\"," config.toml
  sed -i -E "s,(^(cert|private-key)\s*=\s*\").+,\1$STALWART_BASE\"," common/tls.toml
  { set +x; } 2>/dev/null
  ;;
esac
## Enable stdoud logging
set -x
sed -i -E -e 's,^([^#]),#\1,g' -e '5,8s/^#//' common/tracing.toml
## Cleanup
rm -fr spamfilter/ certs/ directory/ldap.toml directory/memory.toml
{ set +x; } 2>/dev/null

DKIM_FILES=$(find dkim -type f -printf '      - %f=%p\n')
export DKIM_FILES

CONFIG_FILES=$(find . -name '*.toml' -printf '      - %P=%P\n' | sed 's,/,_,')
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
$CONFIG_FILES" > kustomization.yaml

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
  ]' > ../volume-mounts.patch.yaml

## Update ingress patch
STALWART_HOST=$(grep -E '^host' config.toml | cut -d\" -f2)
export STALWART_HOST
yq '.[0].value = env(STALWART_HOST)' -i ../ingress.patch.yaml
