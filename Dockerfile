FROM alpine:3.6

MAINTAINER Trevor Hartman <trevorhartman@gmail.com>

WORKDIR /

# Enable SSL
RUN apk --update add ca-certificates wget python curl tar

# Install gcloud and kubectl
# kubectl will be available at /google-cloud-sdk/bin/kubectl
# This is added to $PATH
ENV HOME /
ENV PATH /google-cloud-sdk/bin:$PATH
ENV CLOUDSDK_PYTHON_SITEPACKAGES 1
RUN wget https://dl.google.com/dl/cloudsdk/channels/rapid/google-cloud-sdk.zip && unzip google-cloud-sdk.zip && rm google-cloud-sdk.zip
RUN google-cloud-sdk/install.sh --usage-reporting=true --path-update=true --bash-completion=true --rc-path=/.bashrc --additional-components app kubectl alpha beta
# Disable updater check for the whole installation.
# Users won't be bugged with notifications to update to the latest version of gcloud.
RUN google-cloud-sdk/bin/gcloud config set --installation component_manager/disable_update_check true

# Install docker client (copied from https://github.com/docker-library/docker)

ENV DOCKER_CHANNEL stable
ENV DOCKER_VERSION 17.09.1-ce
# TODO ENV DOCKER_SHA256
# https://github.com/docker/docker-ce/blob/5b073ee2cf564edee5adca05eee574142f7627bb/components/packaging/static/hash_files !!
# (no SHA file artifacts on download.docker.com yet as of 2017-06-07 though)

RUN set -ex; \
# why we use "curl" instead of "wget":
# + wget -O docker.tgz https://download.docker.com/linux/static/stable/x86_64/docker-17.03.1-ce.tgz
# Connecting to download.docker.com (54.230.87.253:443)
# wget: error getting response: Connection reset by peer
  apk add --no-cache --virtual .fetch-deps \
    curl \
    tar \
  ; \
  \
# this "case" statement is generated via "update.sh"
  apkArch="$(apk --print-arch)"; \
  case "$apkArch" in \
    x86_64) dockerArch='x86_64' ;; \
    armhf) dockerArch='armel' ;; \
    aarch64) dockerArch='aarch64' ;; \
    ppc64le) dockerArch='ppc64le' ;; \
    s390x) dockerArch='s390x' ;; \
    *) echo >&2 "error: unsupported architecture ($apkArch)"; exit 1 ;;\
  esac; \
  \
  if ! curl -fL -o docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
    echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
    exit 1; \
  fi; \
  \
  tar --extract \
    --file docker.tgz \
    --strip-components 1 \
    --directory /usr/local/bin/ \
  ; \
  rm docker.tgz; \
  \
  apk del .fetch-deps; \
  \
  dockerd -v; \
  docker -v

# Install Helm
ENV VERSION v2.7.0
ENV FILENAME helm-${VERSION}-linux-amd64.tar.gz
ENV HELM_URL https://storage.googleapis.com/kubernetes-helm/${FILENAME}

RUN curl -o /tmp/$FILENAME ${HELM_URL} \
  && tar -zxvf /tmp/${FILENAME} -C /tmp \
  && mv /tmp/linux-amd64/helm /bin/helm \
  && rm -rf /tmp

# Helm plugins require git
# helm-diff requires bash, curl
RUN apk --update add git bash

# Install Helm plugins
RUN helm init --client-only
# Plugin is downloaded to /tmp, which must exist
RUN mkdir /tmp
RUN helm plugin install https://github.com/databus23/helm-diff
