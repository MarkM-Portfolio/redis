#!/bin/bash

ARTIFACTORY_HOST_IP=$(dig +short artifactory.cwp.pnp-hcl.com)

REDIS_IMAGE_NAME=middleware-redis

docker_build_redis() {
    
        echo 'docker_build_redis: building'
        
	docker build --no-cache --build-arg ARTIFACTORY_HOST_IP=$ARTIFACTORY_HOST_IP \
            --build-arg ARTIFACTORY_USER=$ARTIFACTORY_USER \
            --build-arg ARTIFACTORY_PASS=$ARTIFACTORY_PASS \
            -t connections-docker.artifactory.cwp.pnp-hcl.com/$REDIS_IMAGE_NAME \
            -t connections-docker.artifactory.cwp.pnp-hcl.com/$REDIS_IMAGE_NAME:$TIMESTAMP .

        #Check Build is successful
        if [ $? -eq 0 ]; then
	    echo "Build Successful!"
	else
	    echo "Build Failed!"
	    exit 1
	fi

	if [ $IS_FEATURE == true ] && [ $DEBUG_BUILD_ALL != true ]; then
        	echo 'docker_build_redis: skipping'
	else

        	docker push connections-docker.artifactory.cwp.pnp-hcl.com/$REDIS_IMAGE_NAME:$TIMESTAMP

		#Check Push is successful
        	if [ $? -eq 0 ]; then
	    		echo "Push Successful!"
		else
		    	echo "Push Failed!"
	    		exit 1
		fi

	
        	docker push connections-docker.artifactory.cwp.pnp-hcl.com/$REDIS_IMAGE_NAME

		#Check Push is successful
        	if [ $? -eq 0 ]; then
	 	   	echo "Push Successful!"
		else
	   	 	echo "Push Failed!"
	    		exit 1
		fi


        	
    	fi
}

docker_build_redis
