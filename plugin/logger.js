exports.before = function(request, res, next) {
  res.logger = {
    start: new Date().getTime(),
    url: request.url,
    method: request.method
  };
  return next();
};

exports.after = function(response, res, next) {
  const spend = new Date().getTime() - res.logger.start;
  console.log(`${res.logger.method} ${res.logger.url} ${response.statusCode} ${spend}ms`);
  return next();
};
