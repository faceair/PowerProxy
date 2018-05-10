let Pluggable;
const async = require('async');
const _ = require('lodash');
const {EventEmitter} = require('events');

module.exports = (Pluggable = class Pluggable extends EventEmitter {
  use(...fns) {
    if (_.isUndefined(this.container)) { this.container = []; }

    let match_param = _.first(fns);
    if (_.isRegExp(match_param)) {
      match_param = fns.shift();
    } else if (_.isFunction(match_param)) {
      match_param = /.*/;
    } else if (_.isString(match_param)) {
      try {
        match_param = new RegExp(fns.shift(), 'i');
      } catch (error) {
        throw new Error('Create regexp failed.');
      }
    }

    for (let fn of Array.from(fns)) {
      if (fn) { this.container.push([match_param, fn]); }
    }
    return this;
  }

  run(match_param, ...rest) {
    let adjustedLength = Math.max(rest.length, 1),
      params = rest.slice(0, adjustedLength - 1),
      callback = rest[adjustedLength - 1];
    if (_.isUndefined(this.container)) { this.container = []; }

    if (!_.isFunction(callback)) {
      params = _.union(params, [ callback ]);
      callback = undefined;
    }

    const match = param => {
      return _.filter(this.container, function(...args) {
        let match_param;
        [match_param] = Array.from(args[0]);
        try {
          return param.match(match_param);
        } catch (error) {
          return false;
        }
      });
    };

    async.eachSeries(match(match_param), (...args) => {
      let fn;
      let match_param, callback;
      [match_param, fn] = Array.from(args[0]), callback = args[1];
      try {
        return fn.apply(this, _.union(params, [ callback ]));
      } catch (err) {
        return callback(err);
      }
    }
    , function(err) {
      if (callback) { return callback(err); }
    });

    return this;
  }

  bind(match_param, ...fns) {
    for (let fn of Array.from(fns)) {
      this.on(match_param, fn);
    }
    return this;
  }
});
