#!/bin/bash
set -ex

DEVOPS_URI="https://raw.githubusercontent.com/AndrewMagv/aws-devops/master"

# Install admin tool
apt-get update && apt-get install -y curl htop lvm2 ntp

# source utility file
if [ -f bootstrap/function.sh ]; then
source bootstrap/function.sh
else
eval "`curl -sSL ${DEVOPS_URI}/bootstrap/function.sh`"
fi

AMBASSADOR_VERION=latest
AGENT_VERION=latest
AGENT_NOTIFICATION_URI=
AGENT_NOTIFICATION_CHANNEL="#random"
CLUSTER=
COMMAND="$@"
SWAPSIZE="4G"
REBOOT_NOW="N"
ENVFILE="N"
TRANSPARENT_HUGE_PAGE="N"
while [ $# -gt 0 ]; do
    case ${1} in
        --adduser)
            shift 1; useradd ${1}; shift 1
            ;;
        --dockeruser)
            shift 1; usermod -aG docker ${1}; shift 1
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

# BEGIN configuration

if [ "${ENVFILE}" = "Y" ]; then
    config-envfile
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
