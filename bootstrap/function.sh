#!/bin/bash

get() {
curl -sSL --connect-timeout 1 http://169.254.169.254/latest/meta-data/${1} || echo
}

get-docker-engine() {
# Setup docker engine
truncate -s0 /etc/apt/sources.list.d/docker.list
apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" >>/etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-engine
}

config-docker-engine() {
service docker stop

# FIXME: we do not want conflict names in docker swarm if docker daemon is preinstalled
[ -e /etc/docker/key.json ] && rm -f /etc/docker/key.json

# NOTE: prefer the first available spare disk
dev=`lsblk | grep disk | sed -n '2p' | awk '{print $1}'`
host_bind="-H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375"
storage_opts=

if [ -x /sbin/pvcreate ] && [ ! -z ${dev} ]; then
    [ -d /var/lib/docker ] && rm -rf /var/lib/docker
    pvcreate /dev/${dev}
    vgcreate vg-docker /dev/${dev}
    lvcreate -l 90%FREE -n data vg-docker
    lvcreate -l 10%FREE -n metadata vg-docker
    # Setup DOCKER_OPTS
    storage_opts="--storage-driver=devicemapper --storage-opt dm.datadev=/dev/vg-docker/data --storage-opt dm.metadatadev=/dev/vg-docker/metadata"
fi
truncate -s0 /etc/default/docker
echo DOCKER_OPTS="\"${host_bind} ${storage_opts}\"" >>/etc/default/docker
}

config-swap() {
swapoff -a -v
# Setup swap space
fallocate -l ${SWAPSIZE} /swapfile
chmod 600 /swapfile
mkswap /swapfile
grep -q swap /etc/fstab || echo "/swapfile   none    swap    sw    0   0" >>/etc/fstab
}

config-system() {
truncate -s0 /etc/sysctl.conf
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
}

config-ecs() {
# Seup ecs-agent config
mkdir -p /etc/ecs/
curl -sSL ${DEVOPS_URI}/ecs.config.tmpl -o /etc/ecs/ecs.config
sed -i "s_@CLUSTER@_${CLUSTER}_; s_@MYNAME@_${DOCKER_REGISTRY_USER}_; s_@MYPASS@_${DOCKER_REGISTRY_PASS}_; s_@MYEMAIL@_${DOCKER_REGISTRY_EMAIL}_;" /etc/ecs/ecs.config
}
