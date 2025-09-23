# Redis 

**Release:** Please see the [Dockerfile](Dockerfile) for all notes

This Docker image allows container(s) to be configured by specifying none or one configuration file in the boot command. It means you can use this same image for starting it as Standalone, Master, Slave or a Sentinel instance.


### Build process: 


Building for Artifactory / Integration envs / Cloud

### Clone the repo
```
 git clone git@github.ibm.com:connections/redis.git
 cd redis
 ```
There are 2 images to build
(1) redis 
(2) redis-tester

NB : both will have the same tag

## Building redis - for Artifactory
```
IMAGE_NAME=middleware-redis
TIMESTAMP=$(date +"%Y%m%d-%H%M")
docker build --no-cache \
 -t artifactory.swg.usma.ibm.com:6562/$IMAGE_NAME \
 -t artifactory.swg.usma.ibm.com:6562/$IMAGE_NAME:$TIMESTAMP .

docker push artifactory.swg.usma.ibm.com:6562/$IMAGE_NAME
docker push artifactory.swg.usma.ibm.com:6562/$IMAGE_NAME:$TIMESTAMP
```

## Building redis - for CFC
```
IMAGE_NAME=middleware-redis
TIMESTAMP=$(date +"%Y%m%d-%H%M")
docker build --no-cache \
  -t master.cfc:8500/connections/$IMAGE_NAME \
  -t master.cfc:8500/connections/$IMAGE_NAME:$TIMESTAMP . 

docker push master.cfc:8500/connections/$IMAGE_NAME
docker push master.cfc:8500/connections/$IMAGE_NAME:$TIMESTAMP
```


## Building the redis tester image

### Install node
- On own machine : 
```
curl --silent --location https://rpm.nodesource.com/setup_6.x | sudo bash -
yum install -y nodejs
```

- On Cnext Pool server : 
```
export PATH=/opt/IBM/node/bin:$PATH
```
### Configure .npmrc for download of node modules from Artifactory
```
curl -SLku <your intranet id> https://artifactory.swg.usma.ibm.com/artifactory/api/npm/auth >~/.npmrc
echo registry=\"https://artifactory.swg.usma.ibm.com/artifactory/api/npm/v-ess-npm-dev\"  >> ~/.npmrc
```

### Install NPM Packages
```
npm install
```

### Compile
```
 chmod +x scripts/npm_build.sh
 scripts/npm_build.sh
```
### Build
```
IMAGE_NAME=middleware-redis-tester
docker build --no-cache \
 -t artifactory.swg.usma.ibm.com:6562/$IMAGE_NAME \
 -t artifactory.swg.usma.ibm.com:6562/$IMAGE_NAME:$TIMESTAMP -f Dockerfile.tester .

docker push artifactory.swg.usma.ibm.com:6562/$IMAGE_NAME
docker push artifactory.swg.usma.ibm.com:6562/$IMAGE_NAME:$TIMESTAMP

```
# Helm

## Compiling the helm chart
 - cd deployment/helm
 - helm lint redis

## Packaging the helm chart
 - helm package redis

## Installing the Redis helm chart

For CFC envs
 - helm del --purge redis
 - helm install --name=redis redis-0.1.0.tgz --set image.tag=<docker image tag>, --values=<path to common_values.yaml>

For Cloud envs, use Governor.


## Upgrading the Redis helm chart

For CFC envs
  - helm upgrade redis redis-0.1.1.tgz --set image.tag=<docker image tag> --values=<path to common_values.yaml>



For Cloud envs, use Governor


## Helm Test
 - $ helm test redis

***
# Enable Redis for Applications
 - Add REDIS_OPTIONS as an env variable
    -	a JSON list of Redis configuration data. e.g. redis host and redis port. e.g. redis-options: '{"sentinels": [{"host": "redis-sentinel", "port": 26379 }]}'


 - Add REDIS_AUTH_ENABLED as an env variable 
	
	- Redis Authenication - Default is true.  
	- Requires Redis Secret to be mounted in your container.
	

 - Mount the redis secret
	
	- Mounted as a volume. 
	- If Redis Secret changes, the password will be updated in the mounted secret in the container.  
	- Within your container, redis-secret is available in file : /etc/redis/redis-secret/secret
	

Adhering to good practice when writing applications in 'Pink', we separate application code from configuration. 

We enable application authors to easily access configurations through Kubernetes Config-Map pattern and 'Container' environment variables. Applications can obtain those configurations by setting container environment variables in deployment.yml to Redis configuration parameter
Which are located on full Pink SmartCloud deployment in connections-env Config-Map. See below for sample configuration (located in application's deployment.yml):

```
(...)
  containers:
    - name: NameOfApplication
      image: container_repo_url/connections-docker/application name
      env:
        - name: REDIS_OPTIONS
            valueFrom:
              configMapKeyRef:
                name: connections-env
                key: redis-options 
        - name: REDIS_AUTH_ENABLED
          valueFrom:
            configMapKeyRef:
              name: connections-env
              key: redis-auth-enabled
      volumeMounts:        
        - name: redis-secret-vol
          mountPath: /etc/redis/redis-secret    
  volumes:        
    - name: redis-secret-vol
      secret:
        secretName: redis-secret                
    ............
    .............
    ............. etc
    
(...)
```

# Client Checklist

   - The service can recover from a switch to a new Redis master from a failover/upgrade.  A regular occurrence.
-    The service can recover if Redis and Redis Sentinel is purged and installed?  An irregular occurrence.
 -   The service can connect to either Redis Sentinel or HAProxy
  -  The service can recover from a Redis Password change.  Mount redis secret as a volume
   - The service should consider performance / stability impacts on the Redis Service


For more information : see https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/W28b8df99093e_468e_880f_000d19d33b5c/page/Redis%20-%20Technical%20Documentation


Any issues, submit a git issue
* Label it as component:pipeline and squad: starboard (pipeline) 
