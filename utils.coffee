_             = require('underscore')._

### shared with web site version ###
class UrlBuilder
  ### you may define either {uri} or {isSecure, domain, port, path} ###
  uri:      null
  ### whenever this url uses https ###
  isSecure: false
  domain:   null
  port:     null
  path:     ""
  ### collection of key-value pairs ###
  params:   null

  ### todo zhugrov a - perform validation of input arguments ###
  constructor: (options) ->
    @isSecure  = options.isSecure if  options.isSecure?
    @domain    = options.domain   if  options.domain?
    @port      = options.port     if  options.port?
    @path      = options.path     if  options.path?
    @uri       = options.uri      if  options.uri?
    @params    = new Array()
    return

  on: (name, value) ->
    @params.push(name: name, value: value)
    return this

  url: ->
    throw new Error("Either domain or uri should be set") if _.isNull(@domain) and _.isNull(@uri)
    if (not _.isNull(@domain))
      url =  if @isSecure then "https://" else "http://"
      url += @domain
      url += ":" + @port if not _.isNull(@port)
      url += @path
    else
      url = @uri
    query = new Array()
    for param in @params
      query.push(encodeURIComponent(param.name) + "=" + encodeURIComponent(param.value)) if param.name? and param.value?
    url += "?" + query.join("&") if not _.isEmpty(query)
    return url

exports.UrlBuilder = UrlBuilder