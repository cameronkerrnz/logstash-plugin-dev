IMAGE=cameronkerrnz/logstash-plugin-dev:7.13

.PHONY: all
all: image sbom grype

.PHONY: image
image: Dockerfile
	docker build --progress=plain -t $(IMAGE) .

# docker buildx create --name logstash --driver docker-container --platform linux/arm64,linux/amd64 --bootstrap
# docker buildx inspect logstash
#
# But using QEMU for this is very very slow (ie. 'gradlew assemble' stage of building logstash takes longer than overnight)
#
.PHONY: multiarch
multiarch: Dockerfile
	docker buildx build --platform linux/arm64,linux/amd64 --push -t $(IMAGE) .

.PHONY: sbom
sbom: syft grype

.PHONY: syft
syft:
	syft \
		--output syft-json=sbom/syft.json \
		--output spdx-json=sbom/spdx.json \
		--output cyclonedx-json=sbom/cyclonedx.json \
		--output table=sbom/sbom.txt \
		packages $(IMAGE)

.PHONY: grype
grype: sbom/fixed-vulnerabilities.txt sbom/fixed-vulnerabilities.json sbom/fixed-vulnerabilities-with-path.txt

sbom/fixed-vulnerabilities.txt: sbom/syft.json
	grype --only-fixed --output table --file sbom/fixed-vulnerabilties.txt sbom/syft.json

sbom/fixed-vulnerabilities.json: sbom/syft.json
	grype --only-fixed --output json --file sbom/fixed-vulnerabilties.json sbom/syft.json

sbom/fixed-vulnerabilities-with-path.txt: sbom/syft.json
	jq -r '.matches[]|[.vulnerability.severity, .artifact.name, .artifact.version, .artifact.locations[0].path]|@tsv' \
		sbom/fixed-vulnerabilties.json | sort -u | column -t > sbom/fixed-vulnerabilities-with-path.txt

