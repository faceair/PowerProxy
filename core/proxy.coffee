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

    @cert = new CertificateManager
      cert_path: path.join(utils.getUserHome(), '/.powerproxy')
      cmd_path: path.join(__dirname, '..', './cert/')

    @cert.confirmCertPath()

  setupServer: ->
    @cert.getCertificate @config.proxy.host
    .then ([key, cert]) =>
      @server = https.createServer(key, cert, ->)
