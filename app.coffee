Power = require './core/'

global.power = new Power
  host: '127.0.0.1'
  port: 8001
  plugins: ['logger', 'baidu', 'hosts']
  dns:
    timeout: 1000

power.setup().then ->
  power.startServer()
.catch (err) ->
  throw err
