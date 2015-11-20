#!/bin/bash

if [ -z ${CLUSTER} ]; then
    echo "I need a CLUSTER identity"
    exit 1
fi

docker run -it --rm --link ${CLUSTER}:docker-swarm-daemon \
    -e ETCDCTL_ENDPOINT \
    magvlab/aws-devops
