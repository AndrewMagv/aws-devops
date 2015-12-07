#!/bin/bash

CLUSTER=

case ${1} in
    --cluster)
        shift 1; CLUSTER=${1}; shift 1
        ;;
esac

if [ -z ${CLUSTER} ]; then
    echo "I need a CLUSTER identity"
    exit 1
fi

docker run -it --rm --link ${CLUSTER}:docker-swarm-daemon \
    -e ETCDCTL_ENDPOINT \
    magvlab/aws-devops
