Promise = require 'bluebird'
http = require 'http'
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

  setupUtils: ->
    @utils = require './utils'

  setupCert: ->
    CertificateManager = require './lib/CertificateManager'

    @certmgr = new CertificateManager
      cert_path: path.join(@utils.getUserHome(), '/.powerproxy/')
      cmd_path: path.join(__dirname, '..', './cert/')

    @certmgr.confirmCertPath()

  setupServer: ->
    {connectHandler, requestHandler} = require './lib/Handler'

    @server = http.createServer requestHandler
    @server.on 'connect', connectHandler

  startServer: ->
    @server.listen @config.port, (err) ->
      throw err if err
      console.log 'ProwerProxy is running ...'
