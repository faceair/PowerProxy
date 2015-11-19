Pluggable = require 'node-pluggable'
Promise = require 'bluebird'
http = require 'http'
path = require 'path'
fs = require 'fs'

module.exports = class PowerProxy
  constructor: (@config) ->

  setup: ->
    return Promise.resolve() if @initialized
    @initialized = true

    Promise.resolve()
    .then => @setupUtils()
    .then => @setupPlugin()
    .then => @setupCert()
    .then => @setupServer()

  setupUtils: ->
    @utils = require './utils'

  setupPlugin: ->
    @plugin = new Pluggable()
    for filename in fs.readdirSync(path.join __dirname, '..', 'plugin')
      {before, after} = require path.join(__dirname, '..', 'plugin', filename)
      @plugin.use('before.request', before).use('after.request', after)

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
