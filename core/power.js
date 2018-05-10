let Power;
const Pluggable = require('./plugin');
const Promise = require('bluebird');
const http = require('http');
const path = require('path');
const fs = require('fs');

module.exports = (Power = class Power {
  constructor(config) {
    this.config = config;
  }

  setup() {
    if (this.initialized) { return Promise.resolve(); }
    this.initialized = true;

    return Promise.resolve()
    .then(() => this.setupUtils())
    .then(() => this.setupCache())
    .then(() => this.setupCert())
    .then(() => this.setupDNS())
    .then(() => this.setupServer())
    .then(() => this.setupPlugin());
  }

  setupUtils() {
    return this.utils = require('./utils');
  }

  setupCache() {
    const FileCache = require('./lib/file_cache');

    return this.cache = new FileCache(1024);
  }

  setupPlugin() {
    this.plugin = new Pluggable();

    return (() => {
      const result = [];
      for (let filename of Array.from(this.config.plugins != null ? this.config.plugins : [])) {
        const {before, after} = require(path.join(__dirname, '..', 'plugin', filename));
        result.push(this.plugin.use('before.request', before).use('after.request', after));
      }
      return result;
    })();
  }

  setupCert() {
    const CertificateManager = require('./lib/certificate_manager');

    this.certmgr = new CertificateManager({
      cert_path: path.join(__dirname, '/cert/'),
      cmd_path: path.join(__dirname, '/bin/')
    });

    return this.certmgr.confirmCertPath();
  }

  setupServer() {
    const {connectHandler, requestHandler} = require('./lib/handler');

    this.server = http.createServer(requestHandler);
    return this.server.on('connect', connectHandler);
  }

  setupDNS() {
    const DNSClient = require('./lib/dns_client');

    return this.dns = new DNSClient(this.config.dns);
  }

  startServer() {
    return this.server.listen(this.config.port, this.config.host, function(err) {
      if (err) { throw err; }
      return console.log('ProwerProxy is running ...');
    });
  }
});
