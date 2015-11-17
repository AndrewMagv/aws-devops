#!/bin/bash
set -ex

COMMAND="$@"
ADMIN=
ROLE=
SWAPSIZE="4G"
REBOOT_NOW="N"
ENVFILE="N"
TRANSPARENT_HUGE_PAGE="N"
while [ $# -gt 0 ]; do
    case ${1} in
        --adduser)
            shift 1; ROLE=${1}
            useradd ${ROLE}
            echo "${ROLE}   -   nofile  100000" >>/etc/security/limits.conf
            shift 1
            ;;
        --admin)
            shift 1; ADMIN=${1}
            echo "${ADMIN}  -   nofile  100000" >>/etc/security/limits.conf
            shift 1
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
        --username)
            shift 1; DOCKER_REGISTRY_USER=${1}; shift 1
            ;;
        --passwd)
            shift 1; DOCKER_REGISTRY_PASS=${1}; shift 1
            ;;
        --email)
            shift 1; DOCKER_REGISTRY_EMAIL=${1}; shift 1
            ;;
        *)
            echo "Unexpected option; bootstrap-ecs-instance ${COMMAND}"
            echo "USAGE: bootstrap-ecs-instance [--admin ADMIN --adduser ROLE --swap SWAPSIZE --reboot --thb]"
            exit 1
            ;;
    esac
done

get() {
    curl -sSL --connect-timeout 1 http://169.254.169.254/latest/meta-data/${1} || echo
}

# Install admin tool
yum check-update && yum install -y curl htop lvm2

if [ "${ENVFILE}" = "Y" ]; then
    EC2_INSTANCE_ID=`get instance-id`
    EC2_AVAIL_ZONE="`get placement/availability-zone`"
    EC2_REGION="`echo \"${EC2_AVAIL_ZONE}\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
    echo NODE_NAME=${EC2_INSTANCE_ID} >/etc/environ
    echo NODE_AVAIL_ZONE=${EC2_AVAIL_ZONE} >>/etc/environ
    echo NODE_REGION=${EC2_REGION} >>/etc/environ
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

    chkconfig --add disable-transparent-hugepages
fi

# Adjust server network limit
echo "fs.file-max = 100000" >>/etc/sysctl.conf
echo "net.ipv4.ip_local_port_range = 1024 65535" >>/etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 4096 16777216" >>/etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 4096 16777216" >>/etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 4096" >>/etc/sysctl.conf
echo "net.ipv4.tcp_syncookies = 1" >>/etc/sysctl.conf
echo "net.core.somaxconn = 1024" >>/etc/sysctl.conf

# Seup ecs-agent config
mkdir -p /etc/ecs/
curl -sSL https://raw.githubusercontent.com/AndrewMagv/aws-devops/master/ecs.config.tmpl -o /etc/ecs/ecs.config
sed -i "s_@CLUSTER@_${CLUSTER}_; s_@MYNAME@_${DOCKER_REGISTRY_USER}_; s_@MYPASS@_${DOCKER_REGISTRY_PASS}_; s_@MYEMAIL@_${DOCKER_REGISTRY_EMAIL}_;" /etc/ecs/ecs.config

if [ ${REBOOT_NOW} = "N" ]; then
    read -p "System reboot required...(press enter) "
fi
shutdown -r now
