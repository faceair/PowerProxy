Promise = require 'bluebird'
path = require 'path'

child_process = require 'child_process'
fs = require 'fs'

FileCache = require './FileCache'

module.exports = class CertificateManager
  constructor: ({@cert_path, @cmd_path}) ->
    @cache = new FileCache 1024
    @is_win = /^win/.test process.platform
    if @is_win
      @cmd_gen_root = path.join(@cmd_path, './gen-rootCA.cmd')
      @cmd_gen_cert = path.join(@cmd_path, './gen-cer.cmd')
    else
      @cmd_gen_root = path.join(@cmd_path, './gen-rootCA')
      @cmd_gen_cert = path.join(@cmd_path, './gen-cer')

  confirmCertPath: ->
    Promise.promisify(fs.access) @cert_path, fs.R_OK
    .catch =>
      Promise.promisify(fs.mkdir) @cert_path, '0777'
      .catch ->
        throw new Error 'Cert Path Can Not Write.'
    .then =>
      @isRootCertFileExists()

  isRootCertFileExists: ->
    cert_file = path.join(@cert_path, 'rootCA.crt')
    key_file = path.join(@cert_path, 'rootCA.key')
    Promise.map [key_file, cert_file], (file_path) ->
      Promise.promisify(fs.access) file_path, fs.R_OK
    .catch =>
      @generateRootCert()

  generateRootCert: (callback) ->
    @clearCerts().then =>
      execFile @cmd_gen_root, ['.'], @cert_path

  clearCerts: ->
    if @is_win
      Promise.promisify(child_process.exec) "del #{@cert_path}/* /q"
    else
      Promise.promisify(child_process.exec) "rm -f #{@cert_path}/*.key #{@cert_path}/*.csr #{@cert_path}/*.crt"

  getCertFile: (hostname) ->
    cert_file = path.join(@cert_path, "#{hostname}.crt")
    key_file = path.join(@cert_path, "#{hostname}.key")
    Promise.map [key_file, cert_file], (file_path) =>
      @cache.readFile file_path
    .catch (err) =>
      @createCert(hostname).then =>
        @getCertFile hostname

  createCert: (hostname) ->
    execFile @cmd_gen_cert, [hostname, @cert_path], @cert_path

execFile = (command, args, path) ->
  new Promise (resolve, reject) =>
    spawn_steam = child_process.spawn command, args,
      cwd: path

    spawn_steam.on 'close', (code) ->
      if code is 0
        resolve()
      else
        reject new Error 'Create Certificate Failed.'
    spawn_steam.on 'error', ->
      reject new Error 'Create Certificate Failed.'
