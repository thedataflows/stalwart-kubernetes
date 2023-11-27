#!/bin/env bash

set -e -o pipefail -u -x

cd "${0%/*}"

OUTPUT_DIR=gitops

rm -fr "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
find out/ -type f -name 'v1_secret_*.yaml' -exec cp -v {} "$OUTPUT_DIR" \;
cp -r config/ "$OUTPUT_DIR"
sed -E 's,^# ,,g' templates/kustomization.yaml > "$OUTPUT_DIR/kustomization.yaml"
cd "$OUTPUT_DIR"
SECRETS=$(find -type f -name 'v1_secret_*.yaml' -printf '"%f",')
yq -i '.resources=["https://github.com/thedataflows/stalwart-kubernetes?ref=latest",'$SECRETS'"config/"]' kustomization.yaml
yq -i 'del(.secretGenerator)' config/kustomization.yaml
rm -fr config/data config/etc/dkim
