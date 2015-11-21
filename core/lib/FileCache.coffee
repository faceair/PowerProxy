Promise = require 'bluebird'

_ = require 'lodash'
fs = require 'fs'

module.exports = class FileCache
  constructor: (@size) ->
    @pool = []

  readFile: (file_path, options) ->
    [cache] = _.remove @pool, ({path}) -> file_path is path
    if cache
      @cachePush cache
      return Promise.resolve(cache.content)
    else
      Promise.promisify(fs.readFile) file_path, options
      .then (content) =>
        @cachePush path: file_path, content: content
        return content

  cachePush: (cache) ->
    _.remove @pool, ({path}) -> cache.path is path
    @pool.push cache
    while @pool.length > @size
      @pool = _.rest @pool
