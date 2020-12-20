#!/bin/bash


IMAGE_NAME="difr/oracle-apex:1.1"
CONTAINER_NAME="oracle-apex"
DATA_DIR="/root/oracle-apex-data"

#docker run -itd \
docker run -it \
  -v $DATA_DIR:/u02 \
  -v /dev/hugepages:/dev/hugepages \
  -p 40022:22 \
  -p 41521:1521 \
  -p 48009:8009 \
  -p 48080:8080 \
  --shm-size=1g \
  --ulimit memlock=-1:-1 \
  --restart=unless-stopped \
  --stop-timeout=120 \
  --name $CONTAINER_NAME \
  $IMAGE_NAME
#
# Ctrl+C stops the container.
# You have to exit with Ctrl+P Ctrl+Q if you want to deattach without stopping the container.
#
#docker attach $CONTAINER_NAME

exit 0


#prepare host (ol77)
#echo vm.nr_hugepages = 1024 >>/etc/sysctl.conf
#echo vm/hugetlb_shm_group = 54321 >>/etc/sysctl.conf
echo 1024 > /proc/sys/vm/nr_hugepages
echo 54321 > /proc/sys/vm/hugetlb_shm_group
cat /proc/meminfo | grep -i huge
df -h | grep shm
ulimit -a


docker logs --tail 50 --follow --timestamps oracle-apex
docker container exec -it oracle-apex /bin/bash

docker update --restart=no oracle-apex
docker stop oracle-apex
docker start -ai oracle-apex
