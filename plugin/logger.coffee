exports.before = (before_request_data, next) ->
  before_request_data.logger =
    start: new Date().getTime()
    url: before_request_data.full_url
    method: before_request_data.options.method
  next()

exports.after = (after_request_data, next) ->
  {start, url, method} = after_request_data.logger
  spend = new Date().getTime() - after_request_data.logger.start
  console.log "#{method} #{url} #{after_request_data.status_code} #{spend}ms"
  next()
