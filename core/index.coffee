Promise = require 'bluebird'
https = require 'https'
path = require 'path'

module.exports = class PowerProxy
  constructor: (@config) ->

  setup: ->
    return Promise.resolve() if @initialized
    @initialized = true

    Promise.resolve()
    .then => @setupUtils()
    .then => @setupCert()
    .then => @setupServer()
    .catch (err) ->
      throw err

  setupUtils: ->
    @utils = require './utils'

  setupCert: ->
    CertificateManager = require './lib/CertificateManager'

    @certmgr = new CertificateManager
      cert_path: path.join(@utils.getUserHome(), '/.powerproxy')
      cmd_path: path.join(__dirname, '..', './cert/')

    @certmgr.confirmCertPath()

  setupServer: ->
    {connectHandler, requestHandler} = require './lib/Handler'

    @certmgr.getCertFile @config.proxy.host
    .then ([key, cert]) =>
      @server = https.createServer key, cert, requestHandler
      @server.on 'connect', connectHandler

  startServer: ->
    @server.listen @config.proxy.port