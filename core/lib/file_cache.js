let FileCache;
const Promise = require('bluebird');

const _ = require('lodash');
const fs = require('fs');

module.exports = (FileCache = class FileCache {
  constructor(size) {
    this.size = size;
    this.pool = [];
  }

  readFile(file_path, options) {
    const [cache] = Array.from(_.remove(this.pool, ({path}) => file_path === path));
    if (cache) {
      this.cachePush(cache);
      return Promise.resolve(cache.content);
    } else {
      return Promise.promisify(fs.readFile)(file_path, options)
      .then(content => {
        this.cachePush({path: file_path, content});
        return content;
      });
    }
  }

  cachePush(cache) {
    _.remove(this.pool, ({path}) => cache.path === path);
    this.pool.push(cache);
    return (() => {
      const result = [];
      while (this.pool.length > this.size) {
        result.push(this.pool = _.rest(this.pool));
      }
      return result;
    })();
  }
});
