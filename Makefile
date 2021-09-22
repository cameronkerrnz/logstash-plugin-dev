.PHONY: image

image: Dockerfile
	docker build --progress=plain -t cameronkerrnz/logstash-plugin-dev:7.13 .
