FROM alpine:latest

WORKDIR /root

RUN apk update && \
    apk add bash curl docker-cli docker-cli-compose git jq make openssl zip unzip

COPY ./scripts/ /usr/local/bin