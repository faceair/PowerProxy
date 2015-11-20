url = require 'url'

exports.before = (request, res, next) ->
  res.logger =
    start: new Date().getTime()
    url: url.format(request.uri)
    method: request.method
  next()

exports.after = (response, res, next) ->
  spend = new Date().getTime() - res.logger.start
  console.log "#{res.logger.method} #{res.logger.url} #{response.statusCode} #{spend}ms"
  next()
