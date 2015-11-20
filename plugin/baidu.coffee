url = require 'url'

exports.before = (request, res, next) ->
  if /baidu\.com/i.test url.parse(request.url).hostname
    res.send '<a href="http://www.zhihu.com/question/29740126">珍爱生命, 远离百毒</a>'
  else
    next()
