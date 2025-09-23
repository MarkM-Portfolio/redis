#!/bin/bash

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
else
  /usr/local/bin/redis-cli -p $INSTANCE_PORT ping | grep PONG
fi
