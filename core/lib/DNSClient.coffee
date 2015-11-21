Promise = require 'bluebird'
dns = require 'native-dns'
_ = require 'lodash'

module.exports = class DNSClient
  constructor: (@config) ->

  lookup: (hostname, server) ->
    new Promise (resolve, reject) =>
      if _.isString server
        server = address: server

      dns_req = dns.Request
        question: dns.Question
          name: hostname
          type: 'A'
        server: server
        timeout: @config?.timeout or 1000

      dns_req.on 'timeout', ->
        reject new Error 'DNS Request Timeout.'

      dns_req.on 'message', (err, {answer}) =>
        return reject err if err

        record = _.find answer, (record) -> record.address
        if record
          resolve record.address
        else
          resolve null

      dns_req.send()
