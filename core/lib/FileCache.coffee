Promise = require 'bluebird'

_ = require 'lodash'
fs = require 'fs'

module.exports = class FileCache
  constructor: (@size) ->
    @pool = []

  readFile: (file_path) ->
    [cache] = _.remove @pool, ({path}) file_path is path
    if cache
      @cachePush cache
      return cache.content
    else
      Promise.promisify(fs.readFile) path
      .then (content) =>
        @cachePush path: file_path, content: content
        return content

  cachePush: (cache) ->
    @pool.push cache
    while @pool.length > @size
      @pool = _.rest @pool
