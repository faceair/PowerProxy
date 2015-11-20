_ = require 'lodash'

exports.getUserHome = ->
  return process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE

exports.lowerKeys = (object) ->
  for key of object
    value = object[key]
    delete object[key]
    object[key.toLowerCase()] = value
  return object

exports.extendRes = (res) ->
  res.get = (field) ->
    res.getHeader field

  res.status = (status) ->
    res.statusCode = status
    return res

  res.set = res.header = (name, value) ->
    headers = name
    unless _.isObject headers
      headers = {}
      headers[name] = value
    for name, value of headers
      res.setHeader name, value
    return res

  res.send = (status, data) ->
    unless _.isNumber status
      [status, data] = [null, status]

    unless res.get('Content-Type')
      res.set 'Content-Type', 'text/html; charset=utf-8'
    res.statusCode = status if status
    res.end data

  res.redirect = (url, status = 302) ->
    res.statusCode = status
    res.set 'location', url
    res.end()

  return res
