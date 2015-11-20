Promise = require 'bluebird'
dns = require 'native-dns'
_ = require 'lodash'

module.exports = class DNSClient
  constructor: (@config) ->
    @pool = []

  lookup: (hostname, server) ->
    new Promise (resolve, reject) =>

      record = _.find @pool, (record) ->
        return record.hostname is hostname and record.expired_at > new Date().getTime()
      if record
        return resolve record.address

      dns_req = dns.Request
        question: dns.Question
          name: hostname
          type: 'A'
        server: server
        timeout: @config?.timeout or 1000

      dns_req.on 'timeout', =>
        reject new Error 'DNS Request Timeout.'

      dns_req.on 'message', (err, {answer}) =>
        return reject err if err

        record = _.find answer, (record) -> record.address
        if record
          resolve record.address
          @cachePush
            hostname: hostname
            address: record.address
            expired_at: new Date().getTime() + record.ttl * 1000
        else
          resolve null

      dns_req.send()

  cachePush: (record) ->
    _.remove @pool, ({expired_at, hostname}) -> hostname is record.hostname or expired_at < new Date().getTime()
    @pool.push record
