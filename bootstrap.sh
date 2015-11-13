#!/bin/bash
set -ex

COMMAND="$@"
ADMIN=
ROLE=
SWAPSIZE="4G"
REBOOT_NOW="N"
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
        *)
            echo "Unexpected option; bootstrap ${COMMAND}"
            echo "USAGE: bootstrap [--admin ADMIN --adduser ROLE --swap SWAPSIZE --reboot --thb]"
            exit 1
            ;;
    esac
done

# Install admin tool
apt-get update && apt-get install -y curl htop lvm2

EC2_INSTANCE_ID="`curl -sSL http://169.254.169.254/latest/meta-data/instance-id`"
EC2_AVAIL_ZONE="`curl -sSL http://169.254.169.254/latest/meta-data/placement/availability-zone`"
EC2_REGION="`echo \"${EC2_AVAIL_ZONE}\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
echo NODE_NAME=${EC2_INSTANCE_ID} >/etc/environ
echo NODE_AVAIL_ZONE=${EC2_AVAIL_ZONE} >>/etc/environ
echo NODE_REGION=${EC2_REGION} >>/etc/environ

# Setup docker engine
apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
truncate -s0 /etc/apt/sources.list.d/docker.list
echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" >>/etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-engine
[ -z ${ADMIN} ] || usermod -aG docker ${ADMIN}

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
echo "fs.file-max = 100000" >>/etc/sysctl.conf
echo "net.ipv4.ip_local_port_range = 1024 65535" >>/etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 4096 16777216" >>/etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 4096 16777216" >>/etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 4096" >>/etc/sysctl.conf
echo "net.ipv4.tcp_syncookies = 1" >>/etc/sysctl.conf
echo "net.core.somaxconn = 1024" >>/etc/sysctl.conf

if [ ${REBOOT_NOW} = "N" ]; then
    read -p "System reboot required...(press enter) "
fi
shutdown -r now
