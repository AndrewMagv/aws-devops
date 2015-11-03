#!/bin/bash
set -ex

COMMAND="$@"
ADMIN=
ROLE=
SWAPSIZE="4G"
REBOOT_NOW="N"
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
        --up-to-date)
            shift 1; apt-get update && apt-get upgrade -y;
            ;;
        --reboot)
            shift 1; REBOOT_NOW="Y"
            ;;
        *)
            echo "Unexpected option; bootstrap ${COMMAND}"
            echo "USAGE: bootstrap [--admin ADMIN --adduser ROLE --swap SWAPSIZE --up-to-date --reboot]"
            exit 1
            ;;
    esac
done

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

# Adjust kernel behavior on memory management
echo "vm.overcommit_memory = 1" >>/etc/sysctl.conf
cat <<EOF  >/etc/rc.local
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if [ -f /sys/kernel/mm/transparent_hugepage/defrag ]; then
    echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
EOF

# Adjust server network limit
echo "fs.file-max = 999999" >>/etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 4096 16777216" >>/etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 4096 16777216" >>/etc/sysctl.conf
echo "${ADMIN}  -   nofile  999999" >>/etc/security/limits.conf
echo "${ROLE}   -   nofile  999999" >>/etc/security/limits.conf

if [ ${REBOOT_NOW} = "N" ]; then
    read -p "System reboot required...(press enter) "
fi
shutdown -r now
