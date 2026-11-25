FROM alpine:latest

RUN apk add --no-cache cryptsetup fio losetup

COPY run.sh /run.sh

ENTRYPOINT ["/bin/sh", "/run.sh"]
