#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

logErr() {
  logIt "ERRO: " "$@"
}

logInfo() {
  logIt "INFO: " "$@"
}

logIt() {
    echo "$@"
}

usage() {
  logIt ""
  logIt "Usage: bash runRedisTools.sh [OPTION]"
  logIt ""
  logIt "Options are:"
  logIt "--getMaster	- Will return the IP and Pod Address that the Redis Sentinel is Monitoring."
  logIt "--getMyRole	- Provides information on the role of this Redis instance, by returning if this instance is currently a master or a slave."
  logIt "--getAllRoles	- Provides information on the role of all Redis instances in the cluster, by returning info on each instance whether it is currently a master or a slave. Useful for detecting split brain scenarios where multiple redis masters exist."
  logIt ""
}

function getMaster {

        master=$(timeout ${REDIS_CLIENT_TIMEOUT} redis-cli -h ${REDIS_SENTINEL_NODE_SERVICE_NAME} -p ${REDIS_SENTINEL_NODE_SERVICE_PORT} --csv SENTINEL get-master-addr-by-name mymaster | tr ',' ' ' | cut -d' ' -f1 )
        if [[ -n ${master} ]]; then
                sentinelMaster=$(eval getent hosts ${master} |  awk '{ print $2; }')
                echo "Redis Sentinel is monitoring a Redis master at IP ${master} which equates to ${sentinelMaster}"
        fi

}

function getMyRole {
        set +o errexit
        REDIS_AUTH="${REDIS_AUTH_ENABLED:-false}"
        if [ "$REDIS_AUTH" = "true" ]; then
                PODIP=`hostname -i`
                redisPass=$(cat /etc/redis/redis-secret/secret)
                i="$(/usr/local/bin/redis-cli -h ${PODIP} -a $redisPass info replication | grep -e '^role:' | cut -d':' -f2 | tr -d '[:space:]')"
                podName=$(eval getent hosts ${PODIP} |  awk '{ print $2; }')
                echo "PodName : Role"
                echo "--------------"
                echo "${podName}: $i"
        else
                PODIP=`hostname -i`
                i="$(/usr/local/bin/redis-cli -h ${PODIP} info replication | grep -e '^role:' | cut -d':' -f2 | tr -d '[:space:]')"
                podName=$(eval getent hosts ${PODIP} |  awk '{ print $2; }')
                echo "PodName : Role"
                echo "--------------"
                echo "${podName}: $i"
        fi
        set -o errexit
}

function getAllRoles {
        set +o errexit
        NUM_REPLICAS=${NUM_REPLICAS:-3}
        REDIS_AUTH="${REDIS_AUTH_ENABLED:-false}"
        KUBERNETES_CLUSTER_DOMAIN=${KUBERNETES_CLUSTER_DOMAIN:-"cluster.local"}
        declare -a podList
        local replicaCount=0
        while [[ ${replicaCount} -lt ${NUM_REPLICAS} ]]; do
                podName="redis-server-${replicaCount}"
                podList+=($podName)
                let replicaCount=replicaCount+1
        done

        k8s_namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
        if [ "$REDIS_AUTH" = "true" ]; then
                redisPass=$(cat /etc/redis/redis-secret/secret)
                echo "PodName : Role"
                echo "--------------"
                for pod in "${podList[@]}"; do
                        redis_ip="$(eval getent hosts ${pod}.redis-server.${k8s_namespace}.svc.${KUBERNETES_CLUSTER_DOMAIN} | awk '{ print $1; }')"
                        podName=$(eval getent hosts ${redis_ip} |  awk '{ print $2; }')
                        i="$(/usr/local/bin/redis-cli -h ${redis_ip} -a $redisPass info replication | grep -e '^role:' | cut -d':' -f2 | tr -d '[:space:]')"
                        echo "${podName}: $i"
                done

        else
                echo "PodName : Role"
                for pod in "${podList[@]}"; do
                        redis_ip="$(eval getent hosts ${pod}.redis-server.${k8s_namespace}.svc.${KUBERNETES_CLUSTER_DOMAIN} | awk '{ print $1; }')"
                        podName=$(eval getent hosts ${redis_ip} |  awk '{ print $2; }')
                        i="$(/usr/local/bin/redis-cli -h ${redis_ip} info replication | grep -e '^role:' | cut -d':' -f2 | tr -d '[:space:]')"
                        echo "${podName}: $i"
                done
        fi
        set -o errexit
}

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
        --getMaster)
                getMaster
                exit 0
                ;;
        --getMyRole)
                getMyRole
                exit 0
                ;;
        --getAllRoles)
                getAllRoles
                exit 0
                ;;
*)
                usage
                exit 0
                ;;
esac
done

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    usage
    exit 1
fi
