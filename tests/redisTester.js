'use strict';

import { redis } from '@connections/utils-pubsub';
import config from './service-config';

/**
 * Test if can connect to Redis Master using utils-pubsub.  Write and Read a key in Redis
 */
var test_redis_utilsPubSub = function (req, res) {
	console.log("Testing Redis : connecting via utils-pubsub");
	
        const redisClient = redis.makeClient(config.redisConfig.db);
        
  	redisClient.on('ready', function() {
	    console.log('pubsub - ready');
	    redisClient.set('foo', 'bar', function(err, result) {
              console.log(result);
	      if (err) {
        	responseMsg = "Failed Connecting to Redis after trying to set: " + err.message;
	        console.log(responseMsg);
        	redisClient.end();
	        // abort and fail
        	process.exit(1);
	      }
	      redisClient.end();
	    });

	    redisClient.get('foo', function(err, result) {
 	      console.log(result);
	      if (err) {
        	responseMsg = "Failed Connecting to Redis after trying to retrieve with get: " + err.message;
	        console.log(responseMsg); //will display 'value'
        	redisClient.end();
	        // abort and fail
        	process.exit(1);
	      }
	      redisClient.end();
	    });
	  });	
} 

/**
 * Test if Connect to Redis Master and write and read from it - Using auto generated K8s HAProxy Env Variables.
 */
var test_redisHAProxy = function(req, res) {

  var redisAuthPass = null;

  // Default value.
  var isSuccess = 'FAILED';
  var responseMsg = "Master Redis Test Failed: ";

  var redis = require('ioredis');
  var redisClient = null;

  if (process.env.REDIS_AUTH_ENABLED === 'true') {
    var fs = require('fs');
    config.password = fs.readFileSync('/etc/redis/redis-secret/secret', 'utf8');
  }

  var masterConfig = {};
  console.log(process.env.HAPROXY_REDIS_SERVICE_HOST + ':' + process.env.HAPROXY_REDIS_SERVICE_PORT + ':' + process.env.REDIS_AUTH_ENABLED);
  
  // Initial Redis client using environment variables
  config.host = (process.env.HAPROXY_REDIS_SERVICE_HOST) ? process.env.HAPROXY_REDIS_SERVICE_HOST : config.host;
  config.port = (process.env.HAPROXY_REDIS_SERVICE_PORT) ? process.env.HAPROXY_REDIS_SERVICE_PORT : config.port;
  masterConfig = config;
  
  var redisClient = redis.createClient(masterConfig);
  console.log('after creating redisClient.');
  redisClient.on('error', function(err) {
    responseMsg = "Master Redis Test Failed: " + err.message;
    console.log(responseMsg);
    redisClient.end();
    // abort and fail
    process.exit(1);
  });

  redisClient.on('reconnecting', function() {
    console.log('Retrying connection to Redis. Terminating this session.');
    redisClient.end();
  });

  redisClient.on('ready', function() {
    console.log('ready');
    redisClient.set('foo', 'bar', function(err) {
      if (err) {
        responseMsg = "Failed Connecting to Redis after trying to set: " + err.message;
        console.log(responseMsg);
        redisClient.end();
        // abort and fail
        process.exit(1);
      }
      redisClient.end();
    });

    redisClient.get('foo', function(err, result) {
      if (err) {
        responseMsg = "Failed Connecting to Redis after trying to retrieve with get: " + err.message;
        console.log(responseMsg); //will display 'value'
        redisClient.end();
        // abort and fail
        process.exit(1);
      }
      redisClient.end();
    });
  });
}

/**
 * Test if Connect to Redis Master and write and read from it. Redis Sentinel using auto generated  K8s Service Env Variables
 */
var test_redisSentinel = function(req, res) {

  var redisAuthPass = null;

  // Default value.
  var isSuccess = 'FAILED';
  var responseMsg = "Master Redis Test Failed: ";

  var redis = require('ioredis');
  var redisClient = null;

  if (process.env.REDIS_AUTH_ENABLED === 'true') {
    var fs = require('fs');
    config.password = fs.readFileSync('/etc/redis/redis-secret/secret', 'utf8');
  }

  var masterConfig = {};
  console.log(process.env.REDIS_SENTINEL_SERVICE_HOST + ':' + process.env.REDIS_SENTINEL_SERVICE_PORT + ':' + process.env.REDIS_AUTH_ENABLED);
  // Initial Redis client using environment variables
  config.host = (process.env.REDIS_SENTINEL_SERVICE_HOST) ? process.env.REDIS_SENTINEL_SERVICE_HOST : config.host;
  config.port = (process.env.REDIS_SENTINEL_SERVICE_PORT) ? process.env.REDIS_SENTINEL_SERVICE_PORT : config.port;

  var sentinels = 'sentinels';
  masterConfig[sentinels] = [];
  masterConfig[sentinels].push(config);
  masterConfig.name = 'mymaster';
  if (config.password) {
    masterConfig.password = config.password;
  }

  var redisClient = redis.createClient(masterConfig);
  console.log('after creating redisClient.');
  redisClient.on('error', function(err) {
    responseMsg = "Master Redis Test Failed: " + err.message;
    console.log(responseMsg);
    redisClient.end();
    // abort and fail
    process.exit(1);
  });

  redisClient.on('reconnecting', function() {
    console.log('Retrying connection to Redis. Terminating this session.');
    redisClient.end();
  });

  redisClient.on('ready', function() {
    console.log('ready');
    redisClient.set('foo', 'bar', function(err) {
      if (err) {
        responseMsg = "Failed Connecting to Redis after trying to set: " + err.message;
        console.log(responseMsg);
        redisClient.end();
        // abort and fail
        process.exit(1);
      }
      redisClient.end();
    });

    redisClient.get('foo', function(err, result) {
      if (err) {
        responseMsg = "Failed Connecting to Redis after trying to retrieve with get: " + err.message;
        console.log(responseMsg); //will display 'value'
        redisClient.end();
        // abort and fail
        process.exit(1);
      }
      redisClient.end();
    });
  });
}


/**
 * Test if Connect to Redis Master and write and read from it - HAProxy.  Using config map entries from connections-env
 */
var test_redisHAProxyConfigMap = function(req, res) {

  var redisAuthPass = null;

  // Default value.
  var isSuccess = 'FAILED';
  var responseMsg = "Master Redis Test Failed: ";

  var redis = require('ioredis');
  var redisClient = null;

  if (process.env.REDIS_AUTH_ENABLED === 'true') {
    var fs = require('fs');
    config.password = fs.readFileSync('/etc/redis/redis-secret/secret', 'utf8');
  }

  var masterConfig = {};
  console.log(process.env.REDIS_HOST + ':' + process.env.REDIS_PORT + ':' + process.env.REDIS_AUTH_ENABLED);
  
  // Initial Redis client using environment variables
  config.host = (process.env.REDIS_HOST) ? process.env.REDIS_HOST : config.host;
  config.port = (process.env.REDIS_PORT) ? process.env.REDIS_PORT : config.port;
  masterConfig = config;
  
  var redisClient = redis.createClient(masterConfig);
  console.log('after creating redisClient.');
  redisClient.on('error', function(err) {
    responseMsg = "Master Redis Test Failed: " + err.message;
    console.log(responseMsg);
    redisClient.end();
    // abort and fail
    process.exit(1);
  });

  redisClient.on('reconnecting', function() {
    console.log('Retrying connection to Redis. Terminating this session.');
    redisClient.end();
  });

  redisClient.on('ready', function() {
    console.log('ready');
    redisClient.set('foo', 'bar', function(err) {
      if (err) {
        responseMsg = "Failed Connecting to Redis after trying to set: " + err.message;
        console.log(responseMsg);
        redisClient.end();
        // abort and fail
        process.exit(1);
      }
      redisClient.end();
    });

    redisClient.get('foo', function(err, result) {
      if (err) {
        responseMsg = "Failed Connecting to Redis after trying to retrieve with get: " + err.message;
        console.log(responseMsg); //will display 'value'
        redisClient.end();
        // abort and fail
        process.exit(1);
      }
      redisClient.end();
    });
  });
}

/**
 * Test if Connect to Redis Master and write and read from it. Using config map entries for Redis Sentinel
 */
var test_redisSentinelConfigMap = function(req, res) {

  var redisAuthPass = null;

  // Default value.
  var isSuccess = 'FAILED';
  var responseMsg = "Master Redis Test Failed: ";

  var redis = require('ioredis');
  var redisClient = null;

  if (process.env.REDIS_AUTH_ENABLED === 'true') {
    var fs = require('fs');
    config.password = fs.readFileSync('/etc/redis/redis-secret/secret', 'utf8');
  }

  var masterConfig = {};
  console.log(process.env.REDIS_SENTINEL_NODE_SERVICE_NAME + ':' + process.env.REDIS_SENTINEL_NODE_SERVICE_PORT + ':' + process.env.REDIS_AUTH_ENABLED);
  // Initial Redis client using environment variables
  config.host = (process.env.REDIS_SENTINEL_NODE_SERVICE_NAME) ? process.env.REDIS_SENTINEL_NODE_SERVICE_NAME : config.host;
  config.port = (process.env.REDIS_SENTINEL_NODE_SERVICE_PORT) ? process.env.REDIS_SENTINEL_NODE_SERVICE_PORT : config.port;

  var sentinels = 'sentinels';
  masterConfig[sentinels] = [];
  masterConfig[sentinels].push(config);
  masterConfig.name = 'mymaster';
  if (config.password) {
    masterConfig.password = config.password;
  }

  var redisClient = redis.createClient(masterConfig);
  console.log('after creating redisClient.');
  redisClient.on('error', function(err) {
    responseMsg = "Master Redis Test Failed: " + err.message;
    console.log(responseMsg);
    redisClient.end();
    // abort and fail
    process.exit(1);
  });

  redisClient.on('reconnecting', function() {
    console.log('Retrying connection to Redis. Terminating this session.');
    redisClient.end();
  });

  redisClient.on('ready', function() {
    console.log('ready');
    redisClient.set('foo', 'bar', function(err) {
      if (err) {
        responseMsg = "Failed Connecting to Redis after trying to set: " + err.message;
        console.log(responseMsg);
        redisClient.end();
        // abort and fail
        process.exit(1);
      }
      redisClient.end();
    });

    redisClient.get('foo', function(err, result) {
      if (err) {
        responseMsg = "Failed Connecting to Redis after trying to retrieve with get: " + err.message;
        console.log(responseMsg); //will display 'value'
        redisClient.end();
        // abort and fail
        process.exit(1);
      }
      redisClient.end();
    });
  });
}
//kick off - rum in sync

test_redisHAProxy();
test_redisSentinel();  
test_redisHAProxyConfigMap();
test_redisSentinelConfigMap(); 
test_redis_utilsPubSub();
