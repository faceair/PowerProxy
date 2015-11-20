https = require 'https'
net = require 'net'
url = require 'url'
tls = require 'tls'

request = require 'request'
_ = require 'lodash'

{config, utils, certmgr, dns} = Power

exports.requestHandler = (req, res) ->
  res = utils.extendRes res

  is_https = if not _.isUndefined(req.connection.encrypted) and not /^http:/.test(req.url) then true else false

  post_data = []
  req.on 'data', (chunk) ->
    post_data.push chunk
  req.on 'end', ->
    req_data = Buffer.concat(post_data)
    req.headers = utils.lowerKeys req.headers

    options =
      uri: url.parse(if is_https then "https://#{req.headers.host}#{req.url}" else req.url)
      method: req.method.toUpperCase()
      headers: _.extend(req.headers, 'content-length': req_data.length)
      body: req_data
      followRedirect: false
      encoding: null
      forever: /keep-alive/i.test req.headers.connection
      pool:
        maxSockets: 1024
      gzip: true

    Power.plugin.run 'before.request', options, res, (err) ->
      throw err if err

      Promise.resolve().then ->
        if options.dns?.address and options.dns?.port and options.dns?.type
          dns.lookup options.uri.host, options.dns
          .then (address) ->
            options.hostname = address
      .then ->

        request options, (err, proxy_res) ->
          return res.end() if err

          response = _.pick proxy_res, ['statusCode', 'headers', 'body']
          delete response.headers['content-encoding']
          response.headers['content-length'] = response.body.length

          Power.plugin.run 'after.request', response, res, (err) ->
            throw err if err

            res.set(response.headers).send(response.statusCode, response.body)

exports.connectHandler = (req, socket, head) ->
  [host, targetPort] = req.url.split(':')

  port_range = 40000
  getPort = (callback) ->
    port = port_range
    port_range += 1
    server = net.createServer()
    server.listen port, ->
      server.close ->
        callback port
    server.on 'error', ->
      server.close ->
        getPort callback

  SNIPrepareCert = (server_name, callback) ->
    certmgr.getCertFile server_name
    .then ([key, cert]) ->
      callback null, tls.createSecureContext {key, cert}
    .catch callback

  certmgr.getCertFile 'powerproxy_internal_https_server'
  .then ([key, cert]) ->
    getPort (port) ->
      https.createServer
        SNICallback: SNIPrepareCert
        key: key
        cert: cert
      , exports.requestHandler
      .listen(port)

      proxy_conn = net.connect port, '127.0.0.1', ->
        socket.write "HTTP/#{req.httpVersion} 200 OK\r\n\r\n", 'UTF-8', ->
          proxy_conn.pipe(socket)
          socket.pipe(proxy_conn)
