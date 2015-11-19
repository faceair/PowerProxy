BrowserWindow = require 'browser-window'
app = require 'app'
PowerProxy = require './core/'

require('crash-reporter').start()

global.Power = new PowerProxy
  port: 8001
  proxy: 'http://you_proxy_server:1080'

Power.setup().then ->
  Power.startServer()
.catch (err) ->
  throw err

app.on 'window-all-closed', ->
  if process.platform != 'darwin'
    app.quit()

app.on 'ready', ->
  mainWindow = new BrowserWindow
    width: 375
    height: 667
  mainWindow.loadURL 'file://' + __dirname + '/index.html'
  mainWindow.on 'closed', ->
    mainWindow = null
