FROM golang:1.14.1-alpine AS build-env

RUN apk add --update git gcc libc-dev

ENV GO111MODULE=on

ENV GOFLAGS=-mod=vendor
ENV NOTARYPKG github.com/theupdateframework/notary

# Copy the local repo to the expected go path
COPY . /go/src/${NOTARYPKG}
WORKDIR /go/src/${NOTARYPKG}

# Build notary client
RUN go install \
    -tags pkcs11 \
    -ldflags "-w -X ${NOTARYPKG}/version.GitCommit=`git rev-parse --short HEAD` -X ${NOTARYPKG}/version.NotaryVersion=`cat NOTARY_VERSION`" \
    ${NOTARYPKG}/cmd/notary


FROM busybox:latest

# the ln is for compatibility with the docker-compose.yml, making these
# images a straight swap for the those built in the compose file.
RUN mkdir -p /usr/bin /var/lib && ln -s /bin/env /usr/bin/env

COPY --from=build-env /go/bin/notary /usr/bin/notary
COPY --from=build-env /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
COPY --from=build-env /go/src/github.com/theupdateframework/notary/fixtures /var/lib/notary/fixtures
RUN chmod 0600 /var/lib/notary/fixtures/database/*

# Don't run as root
RUN adduser -h /home/ncli -s /bin/sh -D ncli
COPY ./cmd/notary/config.json /home/ncli/.notary/config.json
COPY ./cmd/notary/root-ca.crt /home/ncli/.notary/root-ca.crt
RUN chown -R ncli /home/ncli

WORKDIR /home/ncli
USER ncli

ENTRYPOINT [ "/usr/bin/notary" ]
# CMD [ "-config=/var/lib/notary/fixtures/server-config-local.json" ]
