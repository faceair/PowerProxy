let DNSClient;
const Promise = require('bluebird');
const dns = require('native-dns');
const _ = require('lodash');

module.exports = (DNSClient = class DNSClient {
  constructor(config) {
    this.config = config;
  }

  lookup(hostname, server) {
    return new Promise((resolve, reject) => {
      if (_.isString(server)) {
        server = {address: server};
      }

      const dns_req = dns.Request({
        question: dns.Question({
          name: hostname,
          type: 'A'
        }),
        server,
        timeout: (this.config != null ? this.config.timeout : undefined) || 1000
      });

      dns_req.on('timeout', () => reject(new Error('DNS Request Timeout.')));

      dns_req.on('message', (err, {answer}) => {
        if (err) { return reject(err); }

        const record = _.find(answer, record => record.address);
        if (record) {
          return resolve(record.address);
        } else {
          return resolve(null);
        }
      });

      return dns_req.send();
    });
  }
});
