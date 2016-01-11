FROM ubuntu:latest
MAINTAINER YI-HUNG JEN <yihungjen@gmail.com>

RUN apt-get update && apt-get install -y \
    curl \
    python \
    socat \
    telnet \
    vim \
    zip

# install command line json parser
RUN curl -sSL http://stedolan.github.io/jq/download/linux64/jq -o /usr/local/bin/jq
RUN chmod +x /usr/local/bin/jq

# install template parse and generator
RUN curl -sSL https://github.com/jeffjen/generate/releases/download/v1.0/generate -o /usr/local/bin/generate
RUN chmod +x /usr/local/bin/generate

# install docker client
RUN curl -sSL https://get.docker.com/builds/Linux/x86_64/docker-latest > /usr/local/bin/docker
RUN chmod +x /usr/local/bin/docker

# install docker-compose for local service stack orchestration
RUN curl -sSL https://github.com/docker/compose/releases/download/1.5.1/docker-compose-Linux-x86_64 > /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

ENV DOCKER_HOST tcp://docker-swarm-daemon:2375
ENV DOCKER_TLS_VERIFY ""
ENV DOCKER_CERT_PATH ""

# install etcdctl
RUN curl -sSL https://github.com/coreos/etcd/releases/download/v2.2.1/etcd-v2.2.1-linux-amd64.tar.gz | tar \
    --transform "s@etcd-v2.2.1-linux-amd64@./@" \
    -zxf - -C /usr/local/bin -- etcd-v2.2.1-linux-amd64/etcdctl

ENV ETCDCTL_ENDPOINT ""

# install package manager for python
RUN curl -sSL https://bootstrap.pypa.io/get-pip.py | python -

# install common python packages
RUN pip install awscli virtualenv

RUN apt-get clean

COPY . /aws-devops
WORKDIR /aws-devops
ENV VERSION latest
