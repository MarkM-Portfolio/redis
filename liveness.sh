#!/bin/bash

redis_info () {
  set +e
  REDIS_AUTH="${REDIS_AUTH_ENABLED:-false}"
  if [ "$REDIS_AUTH" = "true" ]; then
  	redisPass=$(cat /etc/redis/redis-secret/secret)
  	redis-cli -h "$1" -a "$redisPass" info replication
  else
	redis-cli -h "$1" info replication
  fi
  set -e
}

redis_info_role () {
  echo "$1" | grep -e '^role:' | cut -d':' -f2 | tr -d '[:space:]'
}

REDIS_AUTH="${REDIS_AUTH_ENABLED:-false}"
if [ "$REDIS_AUTH" = "true" ]; then

  redisPassFromConfFile=$(cat /redis-master/redis.conf | grep requirepass | awk -F' ' '{print $2}' | tr -d '[:space:]')
  if [[ $redisPassFromConfFile == "" ]]; then
        redisPassFromConfFile=$(cat /redis-slave/redis.conf | grep requirepass | awk -F' ' '{print $2}' | tr -d '[:space:]')
  fi
  
  # remove trailing and leading quotes
  redisPassFromConfFile="${redisPassFromConfFile#\"}"
  redisPassFromConfFile="${redisPassFromConfFile%\"}"

  redisPass=$(cat /etc/redis/redis-secret/secret)

  if [[ "${redisPassFromConfFile}" != "${redisPass}" ]]; then
	eval "/usr/local/bin/redis-cli -p $INSTANCE_PORT -a $redisPassFromConfFile CONFIG SET requirepass $redisPass"
	eval "/usr/local/bin/redis-cli -p $INSTANCE_PORT -a $redisPass CONFIG SET masterauth $redisPass"
   	/usr/local/bin/redis-cli -p $INSTANCE_PORT -a $redisPass CONFIG rewrite
  fi
  /usr/local/bin/redis-cli -p $INSTANCE_PORT -a $redisPass ping | grep PONG

  PODIP=`hostname -i`
  i="$(redis_info "$PODIP")"
  if [ -n "$i" ]; then
    if [ "$(redis_info_role "$i")" = 'master' ]; then
      master_ip="$PODIP"
      # Ask the Sentinel for the IP that it believes is the master
      master=$(timeout ${REDIS_CLIENT_TIMEOUT} redis-cli -h ${REDIS_SENTINEL_NODE_SERVICE_NAME} -p ${REDIS_SENTINEL_NODE_SERVICE_PORT} --csv SENTINEL get-master-addr-by-name mymaster | tr ',' ' ' | cut -d' ' -f1
      )
        if [[ -n ${master} ]]; then
	      master="${master//\"}"
              if [[ $master_ip != $master ]]; then
		exit 1
	      fi
  	fi
    fi
    
    if [ "$(redis_info_role "$i")" = 'slave' ]; then
      master_link_status=$(redis-cli -a $redisPass -p ${INSTANCE_PORT} info | grep master_link_status | awk -F':' '{print $2}')
      master_link_status=$(echo $master_link_status|tr -d '\r')
      if [ "${master_link_status}" == "down" ]; then
        exit 1
      fi
    fi
  fi

else
  /usr/local/bin/redis-cli -p $INSTANCE_PORT ping | grep PONG

  PODIP=`hostname -i`
  i="$(redis_info "$PODIP")"
  if [ -n "$i" ]; then
    if [ "$(redis_info_role "$i")" = 'master' ]; then
      master_ip="$PODIP"
      # Ask the Sentinel for the IP that it believes is the master
      master=$(timeout ${REDIS_CLIENT_TIMEOUT} redis-cli -h ${REDIS_SENTINEL_NODE_SERVICE_NAME} -p ${REDIS_SENTINEL_NODE_SERVICE_PORT} --csv SENTINEL get-master-addr-by-name mymaster | tr ',' ' ' | cut -d' ' -f1)
        if [[ -n ${master} ]]; then
              master="${master//\"}"
              if [[ $master_ip != $master ]]; then
                exit 1
              fi
        fi
    fi

    if [ "$(redis_info_role "$i")" = 'slave' ]; then
      master_link_status=$(redis-cli -p ${INSTANCE_PORT} info | grep master_link_status | awk -F':' '{print $2}')
      master_link_status=$(echo $master_link_status|tr -d '\r')
      if [ "${master_link_status}" == "down" ]; then
        exit 1
      fi
    fi
  fi

fi
