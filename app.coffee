PowerProxy = require './core/'

Power = new PowerProxy
  host: '127.0.0.1'
  port: 8001
  plugins: ['logger', 'baidu', 'hosts']
  dns:
    timeout: 1000

Power.setup().then ->
  Power.startServer()
.catch (err) ->
  throw err
