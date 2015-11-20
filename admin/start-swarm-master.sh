#!/bin/bash

if [ -z ${CLUSTER} ]; then
    echo "I need a CLUSTER identity"
    exit 1
fi

if [ -z ${DISCOVERY_URI} ]; then
    echo "I need DISCOVERY_URI identity"
    exit 2
fi

strategy=${1:?"Please tell me placement strategy"}

docker run -d --restart=always --name ${CLUSTER} \
    swarm \
    manage -H tcp://0.0.0.0:2375 --strategy ${strategy} etcd://${DISCOVERY_URI}/${CLUSTER}
