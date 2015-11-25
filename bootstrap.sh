#!/bin/bash
set -ex

DEVOPS_URI="https://raw.githubusercontent.com/AndrewMagv/aws-devops/master"

# Install admin tool
apt-get update && apt-get install -y curl htop lvm2 ntp

# source utility file
eval "`curl -sSL ${DEVOPS_URI}/bootstrap/function.sh`"

AMBASSADOR_VERION=latest
AGENT_VERION=latest
CLUSTER=
COMMAND="$@"
ROLE=
SWAPSIZE="4G"
REBOOT_NOW="N"
ENVFILE="N"
TRANSPARENT_HUGE_PAGE="N"
while [ $# -gt 0 ]; do
    case ${1} in
        --adduser)
            shift 1; ROLE=${1}; useradd ${ROLE}; shift 1
            ;;
        --swap)
            shift 1; SWAPSIZE=${1}; shift 1
            ;;
        --reboot)
            shift 1; REBOOT_NOW="Y"
            ;;
        --thb)
            shift 1; TRANSPARENT_HUGE_PAGE="Y"
            ;;
        --env)
            shift 1; ENVFILE="Y"
            ;;
        --cluster)
            shift 1; CLUSTER=${1}; shift 1
            ;;
        --ambassador)
            shift 1; AMBASSADOR_VERION=${1}; shift 1
            ;;
        --agent)
            shift 1; AGENT_VERION=${1}; shift 1
            ;;
        *)
            echo "Unexpected option; bootstrap ${COMMAND}"
            exit 1
            ;;
    esac
done

# BEGIN configuration

if [ "${ENVFILE}" = "Y" ]; then
    EC2_INSTANCE_ID=`get instance-id`
    EC2_AVAIL_ZONE="`get placement/availability-zone`"
    EC2_PUBLIC_HOSTNAME="`get public-hostname`"
    EC2_PUBLIC_IPV4="`get public-ipv4`"
    EC2_PRIVAITE_IPV4=`get local-ipv4`
    EC2_REGION="`echo \"${EC2_AVAIL_ZONE}\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
    echo NODE_NAME=${EC2_INSTANCE_ID} >>/etc/environment
    echo NODE_AVAIL_ZONE=${EC2_AVAIL_ZONE} >>/etc/environment
    echo NODE_REGION=${EC2_REGION} >>/etc/environment
    echo NODE_PUBLIC_HOSTNAME=${EC2_PUBLIC_HOSTNAME} >>/etc/environment
    echo NODE_PUBLIC_IPV4=${EC2_PUBLIC_IPV4} >>/etc/environment
    echo NODE_PRIVATE_IPV4=${EC2_PRIVAITE_IPV4} >>/etc/environment
fi

# Configure system
config-system

# Configure swap
config-swap

# Install docker
[ -x /usr/bin/docker ] || get-docker-engine

# Configure docker engine
config-docker-engine

# Launch baseline management containers
[ -z ${CLUSTER} ] || launch-agents

if [ ${REBOOT_NOW} = "N" ]; then
    read -p "System reboot required...(press enter) "
fi

# restart now to load new config
shutdown -r now
