.PHONY: kustomize
kustomize:
	rm -fr out/
	mkdir -p out/
	kubectl kustomize -o out/

.PHONY: clean
clean:
	rm -rf out/
	rm -rf chart config/stalwart-install* config/config.toml config/common config/directory config/dkim config/imap config/jmap config/smtp config/kustomization.yaml volume-mounts.patch.yaml
	yq -i '.[0].value="run make config"' ingress.patch.yaml

.PHONY: config
config:
	sh -c config/config.sh

.PHONY: helm
helm: kustomize
	helmify -f out/ chart

.PHONY: deploy
deploy: kustomize
	kubectl apply -f out/
