#!/bin/bash
set -ex

# Install admin tool
apt-get update && apt-get install -y curl htop lvm2 ntp

BOOTSTRAP_VERSION=master
AMBASSADOR_VERION=latest
AGENT_VERION=latest
AGENT_NOTIFICATION_URI=
AGENT_NOTIFICATION_CHANNEL="#random"
CLUSTER=
ETCD_CLUSTER_ENDPOINTS="etcd://10.0.0.253:2379,10.0.2.96:2379,10.0.1.38:2379"
COMMAND="$@"
SWAPSIZE="4G"
REBOOT_NOW="N"
ENVFILE="N"
TRANSPARENT_HUGE_PAGE="N"
ENABLE_DOCKER_USER=
INSATLL_DOCKER_ENGINE_CS="N"
while [ $# -gt 0 ]; do
    case ${1} in
        --version)
            shift 1; BOOTSTRAP_VERSION=${1}; shift 1
            ;;
        --adduser)
            shift 1; useradd ${1}; shift 1
            ;;
        --dockeruser)
            shift 1; ENABLE_DOCKER_USER="${ENABLE_DOCKER_USER} ${1}"; shift 1
            ;;
        --docker-engine-cs)
            shift 1; INSATLL_DOCKER_ENGINE_CS="Y";
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
        --discovery)
            shift 1; ETCD_CLUSTER_ENDPOINTS=${1}; shift 1
            ;;
        --ambassador)
            shift 1; AMBASSADOR_VERION=${1}; shift 1
            ;;
        --agent)
            shift 1; AGENT_VERION=${1}; shift 1
            ;;
        --agent-notify-uri)
            shift 1; AGENT_NOTIFICATION_URI=${1}; shift 1
            ;;
        --agent-notify-channel)
            shift 1; AGENT_NOTIFICATION_CHANNEL=${1}; shift 1
            ;;
        *)
            echo "Unexpected option; bootstrap ${COMMAND}"
            exit 1
            ;;
    esac
done

# source utility file
if [ -f bootstrap/function.sh ]; then
source bootstrap/function.sh
else
ROOT_URI="https://raw.githubusercontent.com/AndrewMagv/aws-devops"
DEVOPS_URI="${ROOT_URI}/${BOOTSTRAP_VERSION}"
eval "`curl -sSL ${DEVOPS_URI}/bootstrap/function.sh`"
fi

# BEGIN configuration

if [ "${ENVFILE}" = "Y" ]; then
    config-envfile
fi

# Configure system
config-system

# Configure swap
config-swap

# Install docker
[ -x /usr/bin/docker ] || if [ "${INSATLL_DOCKER_ENGINE_CS}" = "N" ]; then
    get-docker-engine
else
    get-docker-engine-cs
fi

# Install toolkit
get-toolkit

# Enable users
for u in ${ENABLE_DOCKER_USER}; do
    usermod -aG docker ${u}
done

# Configure docker engine
config-docker-engine

# Launch baseline management containers
[ -z ${CLUSTER} ] || launch-agents

if [ ${REBOOT_NOW} = "N" ]; then
    read -p "System reboot required...(press enter) "
fi

# restart now to load new config
shutdown -r now
