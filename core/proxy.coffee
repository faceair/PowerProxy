Promise = require 'bluebird'
https = require 'https'
path = require 'path'

module.export = class PowerProxy
  constructor: (@config) ->

  setup: ->
    return Promise.resolve() if @initialized
    @initialized = true

    Promise.resolve()
    .then => @setupCert()
    .then => @setupServer()

  setupUtils: ->
    @utils = require './utils'

  setupCert: ->
    CertificateManager = require './lib/cert'

    @certmgr = new CertificateManager
      cert_path: path.join(utils.getUserHome(), '/.powerproxy')
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
