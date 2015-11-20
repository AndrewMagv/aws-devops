#!/bin/bash

if [ -z ${CLUSTER} ]; then
    echo "I need a CLUSTER identity"
    exit 1
fi

if [ -z ${DISCOVERY_URI} ]; then
    echo "I need DISCOVERY_URI identity"
    exit 2
fi

docker run -d --restart=always --name ${CLUSTER} \
    swarm \
    manage -H tcp://0.0.0.0:2375 --strategy binpack etcd://${DISCOVERY_URI}/${CLUSTER}
