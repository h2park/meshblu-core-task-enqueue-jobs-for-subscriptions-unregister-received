_                   = require 'lodash'
async               = require 'async'
http                = require 'http'
SubscriptionManager = require 'meshblu-core-manager-subscription'

class EnqueueJobsForSubscriptionsUnregisterReceived
  constructor: ({datastore,@jobManager,uuidAliasResolver}) ->
    @subscriptionManager ?= new SubscriptionManager {datastore, uuidAliasResolver}

  _doCallback: (request, code, callback) =>
    response =
      metadata:
        responseId: request.metadata.responseId
        code: code
        status: http.STATUS_CODES[code]
    callback null, response

  do: (request, callback) =>
    {fromUuid, toUuid, route} = request.metadata
    if _.some(route, {to: toUuid, from: fromUuid, type: 'unregister.received'})
      return @_doCallback request, 204, callback

    @subscriptionManager.emitterListForType {emitterUuid: toUuid, type: 'unregister.received'}, (error, subscriptions) =>
      return callback error if error?
      return @_doCallback request, 204, callback if _.isEmpty subscriptions

      requests = _.map subscriptions, (subscription) =>
        @_buildRequest {request, subscription}

      async.each requests, @_createRequest, (error) =>
        return callback error if error?
        return @_doCallback request, 204, callback

  _buildRequest: ({request, subscription}) =>
    hop  =
      from: request.metadata.fromUuid
      to: request.metadata.toUuid
      type: 'unregister.received'

    route = _.cloneDeep request.metadata.route ? []
    route.push hop

    return {
      metadata:
        jobType: 'DeliverSubscriptionUnregisterReceived'
        auth:
          uuid: subscription.subscriberUuid
        fromUuid: subscription.emitterUuid
        toUuid: subscription.subscriberUuid
        route: route
        forwardedRoutes: request.metadata.forwardedRoutes
      rawData: request.rawData
    }

  _createRequest: (request, callback) =>
    @jobManager.createRequest 'request', request, callback

module.exports = EnqueueJobsForSubscriptionsUnregisterReceived
