#!/bin/bash
set -o errexit
echo 'Running Governor tests'

# check for split brain
function checkForSplitBrain {
	NUM_REPLICAS=${NUM_REPLICAS:-3}
	REDIS_AUTH="${REDIS_AUTH_ENABLED:-false}"
 	KUBERNETES_CLUSTER_DOMAIN=${KUBERNETES_CLUSTER_DOMAIN:-"cluster.local"}
	declare -a podList
	local replicaCount=0
	local masterCount=0
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
			if [[ "$i" =~ "master" ]]; then
  		              let masterCount=masterCount+1
			fi
                done

        else
                echo "PodName : Role"
                for pod in "${podList[@]}"; do
                        redis_ip="$(eval getent hosts ${pod}.redis-server.${k8s_namespace}.svc.${KUBERNETES_CLUSTER_DOMAIN} | awk '{ print $1; }')"
                        podName=$(eval getent hosts ${redis_ip} |  awk '{ print $2; }')
                        i="$(/usr/local/bin/redis-cli -h ${redis_ip} info replication | grep -e '^role:' | cut -d':' -f2 | tr -d '[:space:]')"
                        echo "${podName}: $i"
			if [[ "$i" =~ "master" ]]; then
                              let masterCount=masterCount+1
                        fi
                done
        fi
	
	echo "master count : $masterCount"
	if [[ ${masterCount} -gt 1 ]]; then
  	      	echo "Multiple Masters found : Split Brain Test : FAIL"
		exit 1
        elif [[ ${masterCount} == 0 ]]; then
		echo "No Master found : FAIL"
		exit 1
	else
        	echo "Split Brain Test : PASS"
	fi
}

node /usr/src/app/tests/redisTester.js

checkForSplitBrain
