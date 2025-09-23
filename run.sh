#!/bin/bash
###################################################################
#	IBM Confidential
#
#	OCO Source Materials
#
#	Copyright IBM Corp. 2016, 2017
#
#	The source code for this program is not published or otherwise
#	divested of its trade secrets, irrespective of what has been
#	deposited with the U.S. Copyright Office.
###################################################################

function testRedis() {
 
 masterToTest=$1
 echo $masterToTest

 # Test if the master returned by the Sentinel Service is reachable

 if [[ "${REDIS_AUTH_ENABLED}" == "true" ]]; then
	REDIS_SECRET=`cat /etc/redis/redis-secret/secret`
 fi

 if [[ "${REDIS_AUTH_ENABLED}" == "true" ]]; then
    response=$(timeout ${REDIS_CLIENT_TIMEOUT} redis-cli -h ${masterToTest} -a ${REDIS_SECRET} ping)
 else
    response=$(timeout ${REDIS_CLIENT_TIMEOUT} redis-cli -h ${masterToTest} ping)
 fi


 if [[ "${response}" == "PONG" ]]; then
    echo "Ping Test : PASSED"

    # Test if the master is really a master
    if [[ "${REDIS_AUTH_ENABLED}" == "true" ]]; then
        redis-cli -h ${masterToTest} -a ${REDIS_SECRET} info replication | grep role | awk -F':' '{print $2}' | grep master
    else
	redis-cli -h ${masterToTest} info replication | grep role | awk -F':' '{print $2}' | grep master
    fi

    if [[ "$?" == "0" ]]; then
   	echo "Master Role Test : PASSED"
    
        # Test if the master is functional
        # set a key
        if [[ "${REDIS_AUTH_ENABLED}" == "true" ]]; then
		redis-cli -h ${masterToTest} -a ${REDIS_SECRET} set foo bar | grep OK
	else
		redis-cli -h ${masterToTest} set foo bar | grep OK
        fi

        if [[ "$?" == "0" ]]; then
        	echo "SET KEY Test : PASSED"
	else
		echo "SET KEY Test : FAILED"
		return 1
        fi 

        # get a key
	if [[ "${REDIS_AUTH_ENABLED}" == "true" ]]; then
                redis-cli -h ${masterToTest} -a ${REDIS_SECRET} get foo | grep bar
        else
                redis-cli -h ${masterToTest} get foo | grep bar
        fi

	if [[ "$?" == "0" ]]; then
                echo "GET KEY Test : PASSED"
        else
		echo "GET KEY Test : FAILED"
	        return 1
        fi

	return 0      
    else
	echo "Master Role Test : FAILED"
	return 1

    fi
 else
	echo "Master Ping Test : FAILED"
	return 1
 fi


}

function launchmaster() {

  if [[ "${REDIS_AUTH_ENABLED}" == "true" ]]; then

  	if [[ ! -e /etc/redis/redis-secret/secret ]]; then
		echo "Error : Authenication is enabled but no redis secret exists. Please mount a volume to /etc/redis/redis-secret.  Exiting."
		exit 1
  	else

		REDIS_SECRET=`cat /etc/redis/redis-secret/secret`

  		echo "requirepass $REDIS_SECRET" >> /redis-master/redis.conf
        	echo "Running Redis with Auth Password."
  	fi
  else
	echo "Running Redis without Auth Password."
  fi

  exec redis-server /redis-master/redis.conf --protected-mode no
}

function redisAuth() {

	role=$1
	redis_type=$2

	if [[ "${redis_type}" == "redis" ]]; then

		if [[ "${REDIS_AUTH_ENABLED}" == "true" ]]; then

  			if [[ ! -e /etc/redis/redis-secret/secret ]]; then
				echo "Error : Authenication is enabled but no redis secret exists. Please mount a volume to /etc/redis/redis-secret.  Exiting."
				exit 1
  			else

				REDIS_SECRET=`cat /etc/redis/redis-secret/secret`

  				echo "requirepass $REDIS_SECRET" >> /redis-${role}/redis.conf
				echo "masterauth $REDIS_SECRET" >> /redis-${role}/redis.conf
        			echo "Running Redis with Auth Password."
				isAuthEnabled=1
  			fi
  		else
			echo "Running Redis without Auth Password."
  		fi
	elif [[ "${redis_type}" == "sentinel" ]]; then
		
		if [[ "${REDIS_AUTH_ENABLED}" == "true" ]]; then

  			if [[ ! -e /etc/redis/redis-secret/secret ]]; then
				echo "Error : Authenication is enabled but no redis secret exists. Please mount a volume to /etc/redis/redis-secret.  Exiting."
				exit 1
  			else

				REDIS_SECRET=`cat /etc/redis/redis-secret/secret`

  				echo "sentinel auth-pass mymaster $REDIS_SECRET" >> ${sentinel_conf}				
        			echo "Running Redis Sentinel with Auth Password."
				isAuthEnabled=1
  			fi
  		else
			echo "Running Redis without Auth Password."
  		fi
	else
		echo "Running Redis without Auth Password." 

	fi
}

function launchstatefulset() {

	NUM_REPLICAS=${NUM_REPLICAS:-3}
	KUBERNETES_CLUSTER_DOMAIN=${KUBERNETES_CLUSTER_DOMAIN:-"cluster.local"}        

	if [[ "${NEWRELIC_ENABLED}" == "true" ]]; then	
		sed -i 's/REPLACE_WITH_REAL_KEY/'$NEWRELIC_API_KEY'/g' /etc/newrelic/newrelic-plugin-agent.cfg
		sed -i 's/REPLACE_WITH_REAL_HOSTNAME/'$HOSTNAME'/g' /etc/newrelic/newrelic-plugin-agent.cfg
        	
		
		if [[ "${REDIS_AUTH_ENABLED}" == "true" ]]; then

			if [[ ! -e /etc/redis/redis-secret/secret ]]; then
				echo "Error : Authenication is enabled but no redis secret exists. Please mount a volume to /etc/redis/redis-secret.  Exiting."
				exit 1
  			else

				REDIS_SECRET=`cat /etc/redis/redis-secret/secret`
				
				sed -i 's/PASSWORD/'password'/g' /etc/newrelic/newrelic-plugin-agent.cfg

  				sed -i 's/REPLACE_WITH_REDIS_SECRET/'$REDIS_SECRET'/g' /etc/newrelic/newrelic-plugin-agent.cfg
  			fi
			
		fi

		newrelic-plugin-agent -c /etc/newrelic/newrelic-plugin-agent.cfg
		
		
	fi

	if [[ -z "$REDIS_CLIENT_TIMEOUT" ]]; then
  		export REDIS_CLIENT_TIMEOUT=10
	fi

        if [[ -z "$REDIS_SLAVE_WAIT_FOR_MASTER_DELAY" ]]; then
  		export REDIS_SLAVE_WAIT_FOR_MASTER_DELAY=10
	fi

        foundMaster=false
	master=NONE
        k8s_namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

        # discover the redis master from the sentinel
        master=$(timeout ${REDIS_CLIENT_TIMEOUT} redis-cli -h ${REDIS_SENTINEL_NODE_SERVICE_NAME} -p ${REDIS_SENTINEL_NODE_SERVICE_PORT} --csv SENTINEL get-master-addr-by-name mymaster | tr ',' ' ' | cut -d' ' -f1
      )
        if [[ -n ${master} ]]; then
	      master="${master//\"}"
	      echo $master	      
              testRedis ${master}		
              if [[ "$?" == "0" ]]; then
	            echo "Master Test (from Sentinel Service) : PASSED"
		    foundMaster=true
	      else
		    echo "Master Test (from Sentinel Service) : FAILED"
	      fi
	fi
	
	# discover a redis master
        if [[ "${foundMaster}" == "false" ]]; then

                echo "Failed to find master by asking the Sentinel. Cycle through Redis Pods to discover a master."
                local counter=0
                local redis_ip=""
		local replicaCount=0
		
		while [[ ${replicaCount} -lt ${NUM_REPLICAS} ]]; do
	                until [[ -n ${redis_ip} || ${counter} = 3 ]]
                	do
                        	redis_ip="$(eval getent hosts redis-server-${replicaCount}.redis-server.${k8s_namespace}.svc.${KUBERNETES_CLUSTER_DOMAIN} | awk '{ print $1; }')"
	                        if [[ -n ${redis_ip} ]]; then
        	                        testRedis ${redis_ip}
                	                if [[ "$?" == "0" ]]; then
                        	                echo "Master Test : redis-server-${replicaCount} : PASSED"
                                	        foundMaster=true
                                        	master=$redis_ip
	                                        break
        	                        else
                	                        echo "Master Test : redis-server-${replicaCount} : FAILED"
                        	        fi
                        	fi
                        	sleep 10
                        	let counter=counter+1
                	done
			
			if [[ "${foundMaster}" == "true" ]]; then	
				break
			else
				let replicaCount=replicaCount+1
			fi
		done

	fi	
	
	# if master not found by asking the sentinel or an existing pod, make me the master
	if [[ "${foundMaster}" == "false" ]]; then
		echo "I'm the master"

		redisAuth master redis

		exec redis-server /redis-master/redis.conf --protected-mode no
	else
		
		if [[ "${master}" == NONE ]]; then

			echo "There is no Redis master to join a slave.  Exiting."
			exit 1
		else
			echo "I'm a slave"
		    
			redisAuth slave redis

 	        	if [[ "${REDIS_AUTH_ENABLED}" == "true" ]]; then
				REDIS_SECRET=`cat /etc/redis/redis-secret/secret`
				redis-cli -h ${master} -a ${REDIS_SECRET} INFO
			
			else
	        	        redis-cli -h ${master} INFO
			fi

        	        if [[ "$?" == "0" ]]; then			

				sed -i "s/%master-ip%/${master}/" /redis-slave/redis.conf
			
				sed -i "s/%master-port%/6379/" /redis-slave/redis.conf	          

				exec redis-server /redis-slave/redis.conf --protected-mode no
  
                	else
				echo "INFO command failed"
			fi
		fi
	fi


}

isAuthEnabled=0


if [[ "${MASTER}" == "true" ]]; then
  launchmaster
  exit 0
fi

if [[ "${STATEFULSET}" == "true" ]]; then
  launchstatefulset
  exit 0
fi

launchmaster
