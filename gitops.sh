#!/bin/env bash

set -e -o pipefail -u

cd "${0%/*}"

set -x
OUTPUT_DIR=gitops

rm -fr "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
{ set +x; } 2>/dev/null
while IFS= read -r -d '' f; do
  set -x
  cp -v "out/$f" "$OUTPUT_DIR/${f/v1_secret_/secret.}"
  { set +x; } 2>/dev/null
done < <(cd out/; find . -type f -name 'v1_secret_*.yaml' -print0)
set -x
cp -vr config/ "$OUTPUT_DIR"
sed -E 's,^# ,,g' templates/kustomization.yaml > "$OUTPUT_DIR/kustomization.yaml"
cd "$OUTPUT_DIR"
{ set +x; } 2>/dev/null
mapfile -t FILES < <(find . -type f -name 'secret.*.yaml' -printf '%f\n')
printf -v SECRETS '"%s",' "${FILES[@]}"
set -x
yq -i '.resources=["https://github.com/thedataflows/stalwart-kubernetes?ref=latest",'$SECRETS'"config/"]' kustomization.yaml
yq -i 'del(.secretGenerator)' config/kustomization.yaml
rm -fr config/data config/etc/dkim
