/* Copyright IBM Corp. 2017  All Rights Reserved.                    */
import { loggerFactory } from '@connections/utils-logger';
import fs from 'fs';

const logConfig = {
  remote: false,
  level: 'trace',
};

const logger = loggerFactory(logConfig);

function getPassword() {
  let password;
  if (process.env.REDIS_AUTH_ENABLED &&
    process.env.REDIS_AUTH_ENABLED.toLowerCase() === 'true') {

    try {
         password = fs.readFileSync('/etc/redis/redis-secret/secret', 'utf8');
    } catch (e) {
      logger.error(e, 'Read redis secret file fail');
    }
  }
  return password;
}

// default redis env for testing with team.
const redis = {
  host: '127.0.0.1',
  port: 30379,
  retryStrategy(times) {
    const password = getPassword();
    if (typeof (password) !== 'undefined' && password != null) {
       this.password = password;
    }    
    const delay = Math.min(times * 50, 2000);
    if (times > 10) {
       logger.info({ redis: { retry: { times, delay, options: this } } });
    }
   
    return delay;
  },
};

module.exports = {
  logConfig,
  redisConfig: {
    db: { redis }
  },
};
