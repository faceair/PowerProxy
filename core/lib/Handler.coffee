https = require 'https'
http = require 'http'
zlib = require 'zlib'
url = require 'url'
net = require 'net'
tls = require 'tls'

_ = require 'lodash'

{config, utils, certmgr, plugin} = Power

exports.requestHandler = (req, res) ->
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

  is_https = if not _.isUndefined(req.connection.encrypted) and not /^http:/.test(req.url) then true else false

  post_data = []
  req.on 'data', (chunk) ->
    post_data.push chunk
  req.on 'end', ->
    req_data = Buffer.concat(post_data)

    full_url = if is_https then "https://#{req.headers.host}#{req.url}" else req.url
    {hostname, port, path} = url.parse full_url

    options =
      url: full_url
      hostname: hostname or req.headers.host
      port: port or req.port or (if is_https then 443 else 80)
      path: path
      method: req.method
      headers: utils.lowerKeys(_.omit(req.headers, ['accept-encoding']))

    options.headers['content-length'] = req_data.length

    plugin.run 'before.request', options, res, ->
      proxy_req = (if is_https then https else http).request options, (proxy_res) ->
        receive_data = []
        proxy_res.on 'data', (chunk) ->
          receive_data.push chunk
        proxy_res.on 'end', ->
          body = Buffer.concat(receive_data)

          resource =
            statusCode: proxy_res.statusCode
            headers: utils.lowerKeys(proxy_res.headers)
            body: body

          is_gzip = /gzip/i.test(resource.headers['content-encoding'])
          if is_gzip
            delete resource.headers['content-encoding']
            zlib.gunzip body, (err, body) ->
              return res.end() if err
              resource.body = body
              plugin.run 'after.request', resource, res, ->
                res.writeHead resource.statusCode, resource.headers
                res.end resource.body
          else
            plugin.run 'after.request', resource, res, ->
              res.writeHead resource.statusCode, resource.headers
              res.end resource.body

      proxy_req.on 'error', ->
        res.end()

      proxy_req.end req_data

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
