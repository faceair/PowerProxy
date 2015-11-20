url = require 'url'

exports.before = (request, res, next) ->
  res.logger =
    start: new Date().getTime()
    url: url.format(request.uri)
    method: request.method
  next()

exports.after = (response, res, next) ->
  {start, url, method} = res.logger
  spend = new Date().getTime() - start
  console.log "#{method} #{url} #{response.statusCode} #{spend}ms"
  next()
