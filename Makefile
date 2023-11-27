.PHONY: kustomize
kustomize:
	rm -fr out/
	mkdir -p out/
	kubectl kustomize -o out/

.PHONY: clean
clean:
	rm -rf stalwart-install* out/ chart/ config/

.PHONY: config
config:
	sh -c ./config.sh

.PHONY: helm
helm: kustomize
	helmify -f out/ chart

.PHONY: install
install: kustomize
	kubectl apply -f out/
