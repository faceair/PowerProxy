Promise = require 'bluebird'
path = require 'path'

child_process = require 'child_process'
fs = require 'fs'

module.exports = class CertificateManager
  constructor: ({@cert_path, @cmd_path}) ->
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

  isRootCertFileExists: ->
    crt_file = path.join @cert_path, 'rootCA.crt'
    key_file = path.join @cert_path, 'rootCA.key'
    Promise.map [crt_file, key_file], (file_path) ->
      Promise.promisify(fs.access) file_path, fs.R_OK
    .catch =>
      @generateRootCert()

  createCert: (hostname) ->
    @isRootCertFileExists()
    .then =>
      execFile @cmd_gen_cert, [hostname, @cert_path], @cert_path

  getCertFile: (hostname) ->
    key_file = path.join(@cert_path, "#{hostname}.key")
    crt_file = path.join(@cert_path, "#{hostname}.crt")

    Promise.map [key_file, crt_file], (file_path) ->
      Promise.promisify(fs.readFile) file_path
    .catch (err) =>
      @createCert(hostname).then =>
        @getCertFile hostname

  generateRootCert: (callback) ->
    @clearCerts().then =>
      execFile @cmd_gen_root, ['.'], @cert_path

  clearCerts: ->
    if @is_win
      Promise.promisify(child_process.exec) "del #{@cert_path}/* /q"
    else
      Promise.promisify(child_process.exec) "rm -f #{@cert_path}/*.key #{@cert_path}/*.csr #{@cert_path}/*.crt"

  getRootCertFilePath: ->
    @isRootCertFileExists()
    .then =>
      return path.join @cert_path, 'rootCA.crt'

execFile = (command, args, path) ->
  new Promise (resolve, reject) =>
    spawn_steam = child_process.spawn command, args,
      cwd: path
    spawn_steam.on 'close', (code) ->
      if code is 0
        resolve()
      else
        reject new Error 'Create Certificate Failed.'
