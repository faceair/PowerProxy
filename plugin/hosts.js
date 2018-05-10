const {Hosts} = require('hosts-parser');
const path = require('path');
const _ = require('lodash');

const {cache} = power;

exports.before = (request, res, next) =>
  cache.readFile(path.join(__dirname, 'hosts.txt'), {encoding: 'utf8'})
  .then(function(content) {
    const hosts = new Hosts(content);
    const record = _.find(hosts.toJSON(), function({hostname, ip}) {
      try {
        return new RegExp(hostname, 'i').test(request.uri.host);
      } catch (e) {
        return false;
      }
    });
    if (record) { request.uri.hostname = record.ip; }
    return next();}).catch(next)
;
