const https = require('https');
const http = require('http');
const zlib = require('zlib');
const net = require('net');
const url = require('url');
const tls = require('tls');

const _ = require('lodash');

const {config, certmgr, dns} = power;

exports.requestHandler = function(req, res) {
  res = extendRes(res);

  const is_https = req.connection.encrypted && !/^http:/.test(req.url);
  req.url = is_https ? `https://${req.headers.host}${req.url}` : req.url;

  const post_data = [];
  req.on('data', chunk => post_data.push(chunk));
  return req.on('end', function() {
    req.body = Buffer.concat(post_data);
    req.headers = lowerKeys(req.headers);

    const options = {
      url: req.url,
      uri: _.pick(url.parse(req.url), ['protocol', 'host', 'hostname', 'port', 'path', 'auth']),
      method: req.method.toUpperCase(),
      headers: _.extend(req.headers, {'content-length': req.body.length}),
      body: req.body
    };

    return power.plugin.run('before.request', options, res, function(err) {
      if (err) { throw err; }
      return Promise.resolve().then(function() {
        if ((options.dns != null ? options.dns.address : undefined) && (options.dns != null ? options.dns.port : undefined) && (options.dns != null ? options.dns.type : undefined)) {
          return dns.lookup(options.uri.host, options.dns)
          .then(address => options.uri.hostname = address);
        }}).then(function() {
        const proxy_options = _.extend(options.uri, _.pick(options, ['method', 'headers', 'agent']));
        const proxy_req = (is_https ? https : http).request(proxy_options, function(proxy_res) {
          const receive_data = [];
          proxy_res.on('data', chunk => receive_data.push(chunk));
          return proxy_res.on('end', function() {
            proxy_res.body = Buffer.concat(receive_data);
            proxy_res.headers = lowerKeys(proxy_res.headers);

            const is_gzip = /gzip/i.test(proxy_res.headers['content-encoding']);

            const response = _.pick(proxy_res, ['statusCode', 'headers', 'body']);

            if (is_gzip) {
              delete response.headers['content-encoding'];
              return zlib.gunzip(response.body, function(err, body) {
                response.headers['content-length'] = body.length;
                response.body = body;
                return power.plugin.run('after.request', response, res, function(err) {
                  if (err) { throw err; }
                  return res.set(response.headers).send(response.statusCode, response.body);
                });
              });
            } else {
              return power.plugin.run('after.request', response, res, function(err) {
                if (err) { throw err; }
                return res.set(response.headers).send(response.statusCode, response.body);
              });
            }
          });
        });

        proxy_req.on('error', function(err) {
          const response = {
            statusCode: 502,
            headers: {},
            body: err.toString()
          };
          return power.plugin.run('after.request', response, res, function(err) {
            if (err) { throw err; }
            return res.set(response.headers).send(response.statusCode, response.body);
          });
        });

        proxy_req.write(options.body);
        return proxy_req.end();
      });
    });
  });
};

exports.connectHandler = function(req, socket, head) {
  const [host, targetPort] = Array.from(req.url.split(':'));

  let port_range = 40000;
  var getPort = function(callback) {
    const port = port_range;
    port_range += 1;
    const server = net.createServer();
    server.listen(port, () =>
      server.close(() => callback(port))
    );
    return server.on('error', () =>
      server.close(() => getPort(callback))
    );
  };

  const SNIPrepareCert = (server_name, callback) =>
    certmgr.getCertFile(server_name)
    .then(function(...args) {
      const [key, cert] = Array.from(args[0]);
      return callback(null, tls.createSecureContext({key, cert}));})
    .catch(callback)
  ;

  return certmgr.getCertFile('powerproxy_internal_https_server')
  .then(function(...args) {
    const [key, cert] = Array.from(args[0]);
    return getPort(function(port) {
      let proxy_conn;
      https.createServer({
        SNICallback: SNIPrepareCert,
        key,
        cert
      }
      , exports.requestHandler)
      .listen(port);

      return proxy_conn = net.connect(port, '127.0.0.1', () =>
        socket.write(`HTTP/${req.httpVersion} 200 OK\r\n\r\n`, 'UTF-8', function() {
          proxy_conn.pipe(socket);
          return socket.pipe(proxy_conn);
        })
      );
    });
  });
};

var lowerKeys = function(object) {
  for (let key in object) {
    const value = object[key];
    delete object[key];
    object[key.toLowerCase()] = value;
  }
  return object;
};

var extendRes = function(res) {
  res.get = field => res.getHeader(field);

  res.status = function(status) {
    res.statusCode = status;
    return res;
  };

  res.set = (res.header = function(name, value) {
    let headers = name;
    if (!_.isObject(headers)) {
      headers = {};
      headers[name] = value;
    }
    for (name in headers) {
      value = headers[name];
      res.setHeader(name, value);
    }
    return res;
  });

  res.send = function(status, data) {
    if (!_.isNumber(status)) {
      [status, data] = Array.from([null, status]);
    }

    if (!res.get('Content-Type')) {
      res.set('Content-Type', 'text/html; charset=utf-8');
    }
    if (status) { res.statusCode = status; }
    return res.end(data);
  };

  res.redirect = function(url, status) {
    if (status == null) { status = 302; }
    res.statusCode = status;
    res.set('location', url);
    return res.end();
  };

  return res;
};
