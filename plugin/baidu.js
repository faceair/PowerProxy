exports.before = function(request, res, next) {
  if (/baidu\.com/i.test(request.uri.host)) {
    return res.send('<a href="http://www.zhihu.com/question/29740126">珍爱生命, 远离百毒</a>');
  } else {
    return next();
  }
};
