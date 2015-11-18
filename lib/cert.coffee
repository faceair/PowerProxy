child_process = require 'child_process'
fs = require 'fs'

async = require 'async'

util = require './utils'

module.exports = class Cert
  constructor: ({@cert_path, @cmd_path}) ->
    @is_win = /^win/.test process.platform
    if @is_win
      @cmd_gen_root = path.join(@cmd_path, './gen-rootCA.cmd')
      @cmd_gen_cert = path.join(@cmd_path, './gen-cer.cmd')
    else
      @cmd_gen_root = path.join(@cmd_path, './gen-rootCA')
      @cmd_gen_cert = path.join(@cmd_path, './gen-cer')

  confirmCertPath: ->
    if fs.existsSync @cert_path
      return true
    else
      try
        fs.mkdirSync @cert_path, 0777
        return true
      catch e
        return false

  isRootCertFileExists: ->
    crt_file = path.join @cert_path, 'rootCA.crt'
    key_file = path.join @cert_path, 'rootCA.key'

    return fs.existsSync(crt_file) and fs.existsSync(key_file)

  createCert = (hostname, callback) ->
    unless @isRootCertFileExists()
      return callback new Error 'Root Cert File Not Found.'

    child_process.exec "#{@cmd_gen_cert} #{hostname} #{certDir}",
      cwd: @cert_path
    , (err, stdout, stderr) ->
      if err
        callback new Error 'Create Certificate Failed.'
      else
        callback()

  getCertificate = (hostname, callback) ->
    key_file = path.join(@cert_path, "#{hostname}.key")
    crt_file = path.join(@cert_path, "#{hostname}.crt")

    async.map [key_file, crt_file], fs.readFile, (err, files) ->
      if err
        @createCert hostname, (err) ->
          if err
            callback err
          else
            @getCertificate hostname, callback
      else
        callback null, files

  generateRootCert: (callback) ->
    @clearCerts (err) ->
      if err
        callback err
      else
        spawn_steam = child_process.spawn @cmd_gen_root, ['.'],
          cwd: @cert_path
          stdio: 'inherit'
        spawnSteam.on 'close', (code) ->
          if code is 0
            callback()
          else
            callback new Error 'Create Root Certificate Failed.'

  clearCerts: (callback) ->
    if @is_win
      child_process.exec 'del * /q', cwd: @cert_path, callback
    else
      child_process.exec 'rm *.key *.csr *.crt', cwd: @cert_path, callback

  getRootCertFilePath: ->
    if @isRootCertFileExists()
      return path.join @cert_path, 'rootCA.crt'
    else
      return null
