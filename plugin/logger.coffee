exports.before = (request, res, next) ->
  res.logger =
    start: new Date().getTime()
    url: request.url
    method: request.method
  next()

exports.after = (resource, res, next) ->
  {start, url, method} = res.logger
  spend = new Date().getTime() - start
  console.log "#{method} #{url} #{resource.statusCode} #{spend}ms"
  next()
