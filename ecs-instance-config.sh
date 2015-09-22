#!/bin/bash

CONFIG=chat-room

while [ $# -gt 0 ]; do
    case ${1} in
        --cfg)
            shift 1; CONFIG=${1}; shift 1
            ;;
        *)
            ;; # TODO: deprecate default behavior
    esac
done

# install AWS client utility
yum install -y aws-cli wget

die() { status=$1; shift; echo "FATAL: $*"; exit $status; }

EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id || die \"wget instance-id has failed: $?\"`"
test -n "$EC2_INSTANCE_ID" || die 'cannot obtain instance-id'
EC2_AVAIL_ZONE="`wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone || die \"wget availability-zone has failed: $?\"`"
test -n "$EC2_AVAIL_ZONE" || die 'cannot obtain availability-zone'
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

echo NODE_NAME=$EC2_INSTANCE_ID >/etc/environment
echo NODE_AVAIL_ZONE=$EC2_AVAIL_ZONE >>/etc/environment
echo NODE_REGION=$EC2_REGION >>/etc/environment

# get the configuration for the ECS agent
aws s3 cp --region ${EC2_REGION} s3://devops.magv.com/launch-config/${CONFIG}/ecs-latest.config /etc/ecs/ecs.config
