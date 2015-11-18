exports.getUserHome = ->
  return process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE

exports.lowerKeys = (object) ->
  for key of object
    value = object[key]
    delete object[key]
    object[key.toLowerCase()] = value
  return object
