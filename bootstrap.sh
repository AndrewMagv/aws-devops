#!/bin/bash
set -ex

COMPOSE_ROOT_URI="https://raw.githubusercontent.com/AndrewMagv/aws-devops"

COMMAND="$@"
ADMIN=
ROLE=
SWAPSIZE="4G"
REBOOT_NOW="N"
ENVFILE="N"
SERVICE_STACK=
DOCKER_AUTH=
TRANSPARENT_HUGE_PAGE="N"
while [ $# -gt 0 ]; do
    case ${1} in
        --adduser)
            shift 1; ROLE=${1}; useradd ${ROLE}; shift 1
            ;;
        --admin)
            shift 1; ADMIN=${1}; shift 1
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
        --stack)
            shift 1; SERVICE_STACK=${1}; shift 1
            ;;
        --dockerauth)
            shift 1; DOCKER_AUTH=${1}; shift 1
            ;;
        *)
            echo "Unexpected option; bootstrap ${COMMAND}"
            echo "USAGE: bootstrap [--admin ADMIN --adduser ROLE --swap SWAPSIZE --reboot --thb]"
            exit 1
            ;;
    esac
done

get() {
    curl -sSL --connect-timeout 1 http://169.254.169.254/latest/meta-data/${1} || echo
}

# Install admin tool
apt-get update && apt-get install -y curl htop lvm2 ntp

if [ "${ENVFILE}" = "Y" ]; then
    EC2_INSTANCE_ID=`get instance-id`
    EC2_AVAIL_ZONE="`get placement/availability-zone`"
    EC2_REGION="`echo \"${EC2_AVAIL_ZONE}\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
    echo NODE_NAME=${EC2_INSTANCE_ID} >/etc/environ
    echo NODE_AVAIL_ZONE=${EC2_AVAIL_ZONE} >>/etc/environ
    echo NODE_REGION=${EC2_REGION} >>/etc/environ
fi

# Setup docker engine
apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
truncate -s0 /etc/apt/sources.list.d/docker.list
echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" >>/etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-engine
[ -z ${ADMIN} ] || usermod -aG docker ${ADMIN}

# Setup docker compose
DOCKER_COMPOSE="https://github.com/docker/compose/releases/download/1.5.1/docker-compose-`uname -s`-`uname -m`"
curl -sSL ${DOCKER_COMPOSE} >/usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# if Auth is provided, login to docker registry
# FIXME: better way??
if [ ! -z ${DOCKER_AUTH} ]; then
    IFS=';' read -r username pass email <<< "${DOCKER_AUTH}"
    docker login -e ${email} -u ${username} -p ${pass}
fi

# Setup swap space
fallocate -l ${SWAPSIZE} /swapfile
chmod 600 /swapfile
mkswap /swapfile
echo "/swapfile   none    swap    sw    0   0" >>/etc/fstab

# Start turning system config
mv /etc/sysctl.conf /etc/sysctl.conf.origin

# Adjust kernel behavior on memory management
echo "vm.overcommit_memory = 1" >>/etc/sysctl.conf
if [ ${TRANSPARENT_HUGE_PAGE} = "N" ]; then
    cat <<EOF >/etc/init.d/disable-transparent-hugepages
#!/bin/sh
### BEGIN INIT INFO
# Provides:          disable-transparent-hugepages
# Required-Start:    $local_fs
# Required-Stop:
# X-Start-Before:    docker
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Disable Linux transparent huge pages
# Description:       Disable Linux transparent huge pages, to improve
#                    database performance.
### END INIT INFO

case $1 in
start)
    if [ -d /sys/kernel/mm/transparent_hugepage ]; then
    thp_path=/sys/kernel/mm/transparent_hugepage
    elif [ -d /sys/kernel/mm/redhat_transparent_hugepage ]; then
    thp_path=/sys/kernel/mm/redhat_transparent_hugepage
    else
    return 0
    fi

    echo 'never' > ${thp_path}/enabled
    echo 'never' > ${thp_path}/defrag

    unset thp_path
    ;;
esac
EOF

    chmod 755 /etc/init.d/disable-transparent-hugepages

    update-rc.d disable-transparent-hugepages defaults
fi

# Adjust server network limit
echo "net.ipv4.ip_local_port_range = 1024 65535" >>/etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 4096 16777216" >>/etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 4096 16777216" >>/etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 4096" >>/etc/sysctl.conf
echo "net.ipv4.tcp_syncookies = 1" >>/etc/sysctl.conf
echo "net.core.somaxconn = 1024" >>/etc/sysctl.conf

echo "fs.file-max = 100000" >>/etc/sysctl.conf
echo "* - nofile 100000" >>/etc/security/limits.conf

# Pull and poplate service stack definition
if [ ! -z ${SERVICE_STACK} ]; then
    SERVICE_URI="${COMPOSE_ROOT_URI}/master/stack/${SERVICE_STACK}"
    curl -sSL -O ${SERVICE_URI}/docker-compose.yml
    curl -sSL -O ${SERVICE_URI}/docker-compose.prod.yml

    export HostIP="`get public-ipv4`"
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
fi

if [ ${REBOOT_NOW} = "N" ]; then
    read -p "System reboot required...(press enter) "
fi

# restart now to load new config
shutdown -r now
