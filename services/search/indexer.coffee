Hook          = require('hook.io').Hook
request       = require('request')
EventEmitter  = require('events').EventEmitter
UrlBuilder    = require('./../../utils').UrlBuilder
_             = require('underscore')._


##todo zhugrov a - remove these constants as they no longer needed
CommandRequestParamName = "action"
DocRequestParamName = "doc"
AddCommand = "add"
DeleteCommand = "delete"
MergeCommand = "merge"
CommitCommand = "commit"
RollbackCommand = "rollback"

### solr rest api wrapper ###
class SolrClient
  ### base url: {http://ls.sl.me/ad/update/json} ###
  url:          null

  constructor: (@url) ->

  add: (doc, callback) ->
    console.log(JSON.stringify(doc))
    c = (e, r, body) ->
      console.log(e)
      console.log(r)
      console.log(body)
      callback.apply(this) if _.isFunction(callback)
      return
    request({
      url:     new UrlBuilder(uri: @url).on('action', 'add').on('doc', JSON.stringify(doc)).url()
      method:  'POST'
    }, c)

    return this

  delete: (id, callback) ->
    ## todo implement this method
    return this

  merge: (callback) ->
    ## todo implement this method
    return this

  commit: (callback) ->
    ## todo implement this method
    return this

  rollback: (callback) ->
    ## todo implement this method
    return this

### transforms an Ad to a format that solr could understand ###
class AdTransformer
  ### model to be transformed into solr document ###
  model: null

  constructor: (@model) ->

  transform: () ->
    _t = this;
    return {
      id:           _t.model.id.toString()
      message:      _t.model.message
      description:  _t.model.description
      price:        [_t.model.price,_t.model.currency].join(',')
      location:     [_t.model.location.latitude, _t.model.location.longitude].join(',')
      state:        _t.model.state.toString()
      searchable:   _t.model.searchable
    }

module.exports = class Indexer extends EventEmitter

  ### responsible for communications with solr backend ###
  solrClient: null

  constructor: (url) ->
    _t = this
    @solrClient  = new SolrClient(url)
    @indexerHook = new Hook(
      name: 'search-indexer'
      debug: false
    )
    @indexerHook.on('indexer-producer::add', (data) ->
      _t.solrClient.add( data )
    )
    @indexerHook.on('hook::ready', () ->
        _t.producerHook = new Hook(
          name: 'indexer-producer'
          debug: false
        )
        _t.producerHook.on('hook::ready', () ->
          _t.emit('ready')
        )
        _t.producerHook.start()
    )
    @indexerHook.start()


  ### submits document to solr index ###
  index: (doc) ->
    console.log('emit new document')
    @producerHook.emit('add', new AdTransformer( doc ).transform() );
    return
