https = require 'https'
http = require 'http'
zlib = require 'zlib'
net = require 'net'
url = require 'url'
tls = require 'tls'

_ = require 'lodash'

{config, certmgr, dns} = Power

exports.requestHandler = (req, res) ->
  res = extendRes res

  is_https = req.connection.encrypted and not /^http:/.test(req.url)
  req.url = if is_https then "https://#{req.headers.host}#{req.url}" else req.url

  post_data = []
  req.on 'data', (chunk) ->
    post_data.push chunk
  req.on 'end', ->
    req.body = Buffer.concat(post_data)
    req.headers = lowerKeys req.headers

    options =
      uri: _.pick(url.parse(req.url), ['protocol', 'host', 'hostname', 'port', 'path', 'auth'])
      method: req.method.toUpperCase()
      headers: _.extend(req.headers, 'content-length': req.body.length)
      body: req.body

    Power.plugin.run 'before.request', options, res, (err) ->
      throw err if err
      Promise.resolve().then ->
        if options.dns?.address and options.dns?.port and options.dns?.type
          dns.lookup options.uri.host, options.dns
          .then (address) ->
            options.uri.hostname = address
      .then ->

        proxy_options = _.extend options.uri, _.omit(options, ['uri', 'body', 'dns'])
        proxy_req = (if is_https then https else http).request proxy_options, (proxy_res) ->
          receive_data = []
          proxy_res.on 'data', (chunk) ->
            receive_data.push chunk
          proxy_res.on 'end', ->
            proxy_res.body = Buffer.concat(receive_data)
            proxy_res.headers = lowerKeys proxy_res.headers

            is_gzip = /gzip/i.test proxy_res.headers['content-encoding']

            response = _.pick proxy_res, ['statusCode', 'headers', 'body']

            if is_gzip
              delete response.headers['content-encoding']
              zlib.gunzip response.body, (err, body) ->
                response.headers['content-length'] = body.length
                response.body = body
                Power.plugin.run 'after.request', response, res, (err) ->
                  throw err if err
                  res.set(response.headers).send(response.statusCode, response.body)
            else
              Power.plugin.run 'after.request', response, res, (err) ->
                throw err if err
                res.set(response.headers).send(response.statusCode, response.body)

        proxy_req.on 'error', ->
          res.end()

        proxy_req.end req.body

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

lowerKeys = (object) ->
  for key of object
    value = object[key]
    delete object[key]
    object[key.toLowerCase()] = value
  return object

extendRes = (res) ->
  res.get = (field) ->
    res.getHeader field

  res.status = (status) ->
    res.statusCode = status
    return res

  res.set = res.header = (name, value) ->
    headers = name
    unless _.isObject headers
      headers = {}
      headers[name] = value
    for name, value of headers
      res.setHeader name, value
    return res

  res.send = (status, data) ->
    unless _.isNumber status
      [status, data] = [null, status]

    unless res.get('Content-Type')
      res.set 'Content-Type', 'text/html; charset=utf-8'
    res.statusCode = status if status
    res.end data

  res.redirect = (url, status = 302) ->
    res.statusCode = status
    res.set 'location', url
    res.end()

  return res
