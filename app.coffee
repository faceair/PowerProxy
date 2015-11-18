BrowserWindow = require 'browser-window'
app = require 'app'
PowerProxy = require './core/'

require('crash-reporter').start()

global.Power = new PowerProxy
  proxy:
    host: '127.0.0.1'
    port: 1080

Power.setup().then -> Power.startServer()

app.on 'window-all-closed', ->
  if process.platform != 'darwin'
    app.quit()

app.on 'ready', ->
  mainWindow = new BrowserWindow(
    width: 375
    height: 667)
  mainWindow.loadURL 'file://' + __dirname + '/index.html'
  mainWindow.on 'closed', ->
    mainWindow = null
