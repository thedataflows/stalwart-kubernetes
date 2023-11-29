# Stalwart Kubernetes

## Introduction

This repository contains the Kubernetes manifests to deploy [Stalwart mail server](https://stalw.art/).

Will deploy in a kubernetes cluster:

- All in one mail server
- TLS enabled using [cert-manager](https://cert-manager.io/) certificates

## Requirements

- Utilities: `bash`, `make`, `sed`, `kubectl`, `yq` [mikefarah's v4 and above](https://github.com/mikefarah/yq/releases), `git`, `curl`, `gzip`, `unzip` (Windows)
- Working kubernetes cluster
- Optional:
  - For helm chart generation: [Helmify](https://github.com/arttor/helmify)
  - For [litestream](https://litestream.io/) any of the following:
    - AWS S3
    - [Minio](https://min.io/) (self hosted or SaaS)
    - [Backblaze Object Storage](https://www.backblaze.com/cloud-storage)
  - [FluxCD](https://fluxcd.io/) client

## Guide

1. Fork this repository
2. Clone it locally `git clone https://github.com/change-me/stalwart-kubernetes.git`
3. Recommended to use [Listestream](https://litestream.io)
   - Keep StatefulSet [replicas to 1](https://litestream.io/guides/kubernetes/#ensure-single-replica)
   - Create a bucket in your S3 compatible storage and set environment variables:
     - `export ACCESS_KEY_ID=value`
     - `export SECRET_ACCESS_KEY=value`
4. Generate configuration: `make config` will download and run `stalwart-install` in interactive mode. In turn this will:
   - Download and modify stalwart toml config files in `config/etc`
   - Generate sqlite databases in `config/data`
   - Generate DKIM cert amd key in `config/etc/dkim` (excluded from git because contains secrets)
5. Update generated stalwart config files as needed:
   - Default user directory is sql:

     ```toml
     config/etc/config.toml:15
     ...
     "%{BASE_PATH}%/etc/directory/sql.toml",
     ...
     ```

   - Can use [other types](https://stalw.art/docs/category/types) instead
6. Update `config/*.patch.yaml` files with your specific configuration:
   - Set `storageClassName` and storage size
   - Enable **litestream**:
     - Comment out the removal of `initContainer/0` and `container/1` in `config/statefulset.patch.yaml`
     - Configure bucket, path, endpoint in `config/listestream.yaml`
7. Deploy manually: `make install`
   - Will deploy in the current kubernetes context. Assumes `kubectl` is present and a local kuberenes context is configured
   - Alternatively, you can just generate the manifests: `make kustomize` and inspect them in `out/` directory.
8. `git commit -am "Set up stalwart for domain yourdomain.org" && git push`
   - > Warning: [config/kustomization.yaml](config/kustomization.yaml) contains a `secretGenerator` section that with plain text secrets. Remove it before pushing to a git repository: `yq -i 'del(.secretGenerator)' config/kustomization.yaml`.
9. Deploy using GitOps (recommended):
   - Using your FluxCD git repo (different from this one):
     - In this repo: `make gitops`
     - Copy `gitops/` to the gitops repoo and encrypt **all** the secrets with [SOPS](https://github.com/getsops/sops/)
   - Using [ArgoCD](https://argoproj.github.io/cd/):
     - TODO
10. Setup DKIM: follow `config/etc/dkim/yourdomain.org.readme` instructions
11. Uninstall manually: `kubectl delete ns stalwart`
12. Cleanup: `make clean` will remove all generated files

## Helm chart

`make helm` will generate a helm chart in `chart/` directory. This is not the preferred way to deploy stalwart and is not tested, but it can be used as a reference.

## License

[MIT License](LICENSE)
