let CertificateManager;
const Promise = require('bluebird');
const path = require('path');

const child_process = require('child_process');
const fs = require('fs');

const {cache} = power;

module.exports = (CertificateManager = class CertificateManager {
  constructor({cert_path, cmd_path}) {
    this.cert_path = cert_path;
    this.cmd_path = cmd_path;
    this.is_win = /^win/.test(process.platform);
    if (this.is_win) {
      this.cmd_gen_root = path.join(this.cmd_path, './gen-rootCA.cmd');
      this.cmd_gen_cert = path.join(this.cmd_path, './gen-cer.cmd');
    } else {
      this.cmd_gen_root = path.join(this.cmd_path, './gen-rootCA');
      this.cmd_gen_cert = path.join(this.cmd_path, './gen-cer');
    }
  }

  confirmCertPath() {
    return Promise.promisify(fs.access)(this.cert_path, fs.R_OK)
    .catch(() => {
      return Promise.promisify(fs.mkdir)(this.cert_path, '0777')
      .catch(function() {
        throw new Error('Cert Path Can Not Write.');
      });
  }).then(() => {
      return this.isRootCertFileExists();
    });
  }

  isRootCertFileExists() {
    const cert_file = path.join(this.cert_path, 'rootCA.crt');
    const key_file = path.join(this.cert_path, 'rootCA.key');
    return Promise.map([key_file, cert_file], file_path => Promise.promisify(fs.access)(file_path, fs.R_OK)).catch(() => {
      return this.generateRootCert();
    });
  }

  generateRootCert(callback) {
    return this.clearCerts().then(() => {
      return execFile(this.cmd_gen_root, ['.'], this.cert_path);
    });
  }

  clearCerts() {
    if (this.is_win) {
      return Promise.promisify(child_process.exec)(`del ${this.cert_path}/* /q`);
    } else {
      return Promise.promisify(child_process.exec)(`rm -f ${this.cert_path}/*.key ${this.cert_path}/*.csr ${this.cert_path}/*.crt`);
    }
  }

  getCertFile(hostname) {
    const cert_file = path.join(this.cert_path, `${hostname}.crt`);
    const key_file = path.join(this.cert_path, `${hostname}.key`);
    return Promise.map([key_file, cert_file], file_path => {
      return cache.readFile(file_path);
  }).catch(err => {
      return this.createCert(hostname).then(() => {
        return this.getCertFile(hostname);
      });
    });
  }

  createCert(hostname) {
    return execFile(this.cmd_gen_cert, [hostname, this.cert_path], this.cert_path);
  }
});

var execFile = (command, args, path) =>
  new Promise((resolve, reject) => {
    const spawn_steam = child_process.spawn(command, args,
      {cwd: path});

    spawn_steam.on('close', function(code) {
      if (code === 0) {
        return resolve();
      } else {
        return reject(new Error('Create Certificate Failed.'));
      }
    });
    return spawn_steam.on('error', () => reject(new Error('Create Certificate Failed.')));
  })
;
