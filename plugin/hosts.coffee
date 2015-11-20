{Hosts} = require 'hosts-parser'
path = require 'path'
_ = require 'lodash'

{cache} = Power

exports.before = (request, res, next) ->
  cache.readFile path.join(__dirname, 'hosts.txt'), encoding: 'utf8'
  .then (content) ->
    hosts = new Hosts content
    record = _.find hosts.toJSON(), ({hostname, ip}) ->
      try
        return new RegExp(hostname, 'i').test request.uri.host
      catch e
        return false
    request.uri.hostname = record.ip if record
    next()
  .catch next
