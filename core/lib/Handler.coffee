https = require 'https'
http = require 'http'
zlib = require 'zlib'
url = require 'url'
net = require 'net'
tls = require 'tls'

HttpsProxyAgent = require 'https-proxy-agent'
HttpProxyAgent = require 'http-proxy-agent'
_ = require 'lodash'

{config, utils, certmgr} = Power

exports.requestHandler = (req, userRes) ->
  is_https = if not _.isUndefined(req.connection.encrypted) and not /^http:/.test(req.url) then true else false

  post_data = []
  req.on 'data', (chunk) ->
    post_data.push chunk

  req.on 'end', ->
    req_data = Buffer.concat(post_data)

    full_url = if is_https then "https://#{req.headers.host}#{req.url}" else req.url
    {hostname, port, path} = url.parse full_url

    options =
      hostname: hostname or req.headers.host
      port: port or req.port or (if is_https then 443 else 80)
      path: path
      method: req.method
      headers: utils.lowerKeys(_.omit(req.headers, ['accept-encoding']))
      agent: if is_https then new HttpsProxyAgent(config.proxy) else new HttpProxyAgent(config.proxy)

    options.headers['content-length'] = req_data.length

    proxy_req = (if is_https then https else http).request options, (res) ->
      post_data = []
      res.on 'data', (chunk) ->
        post_data.push chunk
      res.on 'end', ->
        res_data = Buffer.concat(post_data)

        res_header = utils.lowerKeys(res.headers)
        is_gzip = /gzip/i.test(res_header['content-encoding'])

        if is_gzip
          delete res_header['content-encoding']
          zlib.gunzip res_data, (err, buffer) ->
            userRes.writeHead res.statusCode, res_header
            userRes.end buffer
        else
          userRes.writeHead res.statusCode, res_header
          userRes.end res_data

    proxy_req.on 'error', ->
      userRes.end()

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
