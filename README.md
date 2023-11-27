# Stalwart Kubernetes

## Introduction

This repository contains the Kubernetes manifests to deploy [Stalwart mail server](https://stalw.art/).

Will deploy in a kubernetes cluster:

- All in one mail server
- TLS enabled using [cert-manager](https://cert-manager.io/) certificates

## Requirements

- Utilities: `bash`, `make`, `sed`, `kubectl`, `yq` [mikefarah's v4 and above](https://github.com/mikefarah/yq/releases), `git`, `curl`, `unzip` (Windows)
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
3. Generate configuration: `make config` will download and run `stalwart-install` in interactive mode. In turn this will:
   - Generate [config/](config/)
   - Generate DKIM cert amd key in `config/etc/dkim` (excluded from git because contains secrets)
4. Update the new stalwart config files as needed:
   - Default user directory is sql:

     ```toml
     config/etc/config.toml:15
     ...
     "%{BASE_PATH}%/etc/directory/sql.toml",
     ...
     ```

   - Can use [`ldap` or `memory`](https://stalw.art/docs/category/types) instead
5. Update `config/*.patch.yaml` files with your specific configuration:
   - Set `storageClassName` and storage size
   - Enable [listestream](https://litestream.io/guides/kubernetes/) by commenting out the removal of `container/1` in `statefulset.patch.yaml`
6. `git commit -am "Set up stalwart for domain yourdomain.org" && git push`
7. Deploy manually: `make install`
   - Will deploy in the current kubernetes context. Assumes `kubectl` is present and a local kuberenes context is configured
   - Alternatively, you can just generate the manifests: `make kustomize` and inspect them in `out/` directory.
8. Deploy using GitOps (recommended):
   - Using your FluxCD git repo (different from this one):
     - First time: manually create secrets containing
       - **DKIM** files:

         ```bash
         kubectl -n stalwart \
            create secret generic dkim \
            --from-file=config/dkim \
            --dry-run=client \
            -o yaml
         ```

       - If using **litestream**:

         ```bash
         kubectl -n stalwart \
           create secret generic litestream-s3 \
           --from-literal=ACCESS_KEY_ID=value \
           --from-literal=SECRET_ACCESS_KEY=value \
           --dry-run=client \
           -o yaml
         ```

       - Encrypt the secrets with [SOPS](https://github.com/getsops/sops/) and store them in your gitops repo
     - Create a `stalwart/kustomization.yaml`:

       ```yaml
       apiVersion: kustomize.config.k8s.io/v1beta1
       kind: Kustomization
       resources:
         - https://github.com/change-me/stalwart-kubernetes?ref=main
       ## Create your own local patches or change the ones in the imported repo
       patches:
         - path: mystatefulset.patch.yaml
           target:
             kind: StatefulSet
             name: stalwart
       ```

     - Alternatively, copy `config/` in your gitops repo
     - Or generate manifests with `make kustomize` and copy them from `out/` to your gitops repo and encrypt the secrets with SOPS

   - Using [ArgoCD](https://argoproj.github.io/cd/):
     - TODO

9. Uninstall manually: `kubectl delete ns stalwart`
10. Cleanup: `make clean` will remove all generated files

## Helm chart

`make helm` will generate a helm chart in `chart/` directory. This is not the preferred way to deploy stalwart and is not tested, but it can be used as a reference.

## License

[MIT License](LICENSE)
