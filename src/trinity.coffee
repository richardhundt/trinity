require("trinity/shims")

UriTemplate = require("uritemplate/bin/uritemplate")
Moment      = require("moment")

UUID = {
  generate: ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
      r = Math.random() * 16 | 0
      v = if c == 'x' then r else r & 0x3 | 0x8
      v.toString(16)
}


class Promise
  constructor: ->
    @future = new Future()

  success: (result) ->
    @future.success(result)

  failure: (error) ->
    @future.failure(error)


class Future
  @defer: (block) ->
    promise = new Promise
    setTimeout ->
      try
        promise.success(block(arguments...))
      catch ex
        promise.failure(ex)
    , 0, arguments...
    promise.future

  constructor: (@value) ->

  success: (result) ->
    @onSuccess(result)

  onSuccess: (@value) ->

  failure: (result) ->
    @onFailure(result)

  onFailure: (@error) ->
    throw @error
  
  andThen: (block) ->
    promise = new Promise
    @onSuccess = (result) ->
      try
        promise.success(block(result))
      catch ex
        promise.failure(ex)
    @onFailure = (error) ->
      promise.failure(error)

    # already completed
    if @error?
      @onFailure(@error)
    else if @value?
      @onSuccess(@value)

    promise.future

  failAnd: (block) ->
    @onFailure = block
    if @error?
      @onFailure(@error)


class HtmlBuilder

  util = document.createElement('div')

  constructor: (@frag) ->
    @frag ?= document.createDocumentFragment()
    @curr = @frag

  appendTo: (elmt) ->
    elmt.appendChild(@frag)

  replace: (elmt) ->
    elmt.parentNode.replaceChild(@frag, elmt)

  replaceInner: (elmt) ->
    elmt.removeChild(elmt.firstChild) while elmt.firstChild
    elmt.appendChild(@frag)

  text: (value) ->
    node = document.createTextNode(value)
    @curr.appendChild(node)
    node

  pure: (elmt) ->
    @curr.appendChild(elmt)

  entity: (value) ->
    util.innerHTML = "&#{value};"
    node = util.firstChild
    util.innerHTML = ""
    @curr.appendChild(node)
    node

  element: (name, atts, body) ->
    if typeof atts == 'function'
      body = atts
      atts = { }

    elmt = document.createElement(name)
    for own k of atts
      if typeof atts[k] == "function"
        elmt[k] = atts[k]
      else
        elmt.setAttribute(k, atts[k])

    if typeof body == 'function'
      save = @curr
      @curr = elmt
      body(elmt)
      @curr = save

    @curr.appendChild(elmt)
    elmt

  tags = """
    a abbr address article aside audio b bdi bdo blockquote body button
    canvas caption cite code colgroup datalist dd del details dfn div dl dt em
    fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 head header hgroup
    html i iframe ins kbd label legend li map mark menu meter nav noscript object
    ol optgroup option output p pre progress q rp rt ruby s samp script section
    select small span strong style sub summary sup table tbody td textarea tfoot
    th thead time title tr u ul video area base br col command embed hr img input
    keygen link meta param source track wbr
  """.split(/\s+/)

  for name in tags
    do (name) =>
      @::[name] = (atts, body) ->
        @element(name, atts, body)

UI =
  builder: new HtmlBuilder

  build: (block, args...) ->
    block(@builder, args...)

  buildOn: (parent, block, args...) ->
    retv = block(@builder, args...)
    @builder.appendTo(parent)
    retv


class HttpRequest
  constructor: (@server) ->
    @headers = [ [ "Accept", "application/json, text/plain, */*" ] ]

  withHeaders: (hdrs) ->
    @headers.push(hdrs)
    return this

  request: (meth, data, async = true) ->
    req = new XMLHttpRequest
    prm = null
    if async
      prm = new Promise
      req.onload = () ->
        prm.success(req)

    req.open(meth, @server, async)
    for header in @headers
      [key, val] = header
      req.setRequestHeader(key, val)

    if data and typeof data is 'object'
      data = JSON.stringify(data)
      req.setRequestHeader('Content-Type', 'application/json')

    req.send(data)
    if async
      return prm.future
    else
      return req

  get: (async) -> @request('GET', null, async)

  put: (data, async) -> @request('PUT', data, async)

  post: (data, async) -> @request('POST', data, async)

  head: (async) -> @request('HEAD', null, async)

  delete: (async) -> @request('DELETE', null, async)

  options: (async) -> @request('OPTIONS', null, async)

WS = url: (url) -> new HttpRequest(url)


class AppEvent
  constructor: (type, opts) ->
    if opts
      for own k of opts
        @[k] = opts[k]
    @type = type

  stopPropagation: ->
    @$stopped = true


class Component
  @include = ->
    for that in arguments
      for k, v of that when k != 'included'
        @::[k] = v
      that.included?(@)
    return

  constructor: ->
    @eventListeners = { }

  addEventListener: (type, listener) ->
    @eventListeners[type] ?= [ ]
    listeners = @eventListeners[type]
    if listeners.indexOf(listener) < 0
      listeners.push(listener)
    return

  removeEventListener: (type, listener) ->
    return unless @eventListeners[type]
    listeners = @eventListeners[type]
    idx = listeners.indexOf(listener)
    listeners.splice(idx, 1) if idx >= 0
    return

  dispatchEvent: (evt) ->
    evt.target = @
    curr = @
    while curr
      evt.currentTarget = curr
      curr.handleEvent(evt)
      return if evt.$stopped
      curr = curr.parent
    return

  handleEvent: (evt) ->
    return unless @eventListeners[evt.type]
    listeners = @eventListeners[evt.type]
    for listener in listeners
      listener.call(@, evt)
    return
 

class Route extends Component

  constructor: (@parent, @pattern) ->
    super
    window.addEventListener 'hashchange', @onHashChange

  onHashChange: =>
    hash = location.hash.substr(1).split('/').map(decodeURIComponent)
    patt = @pattern.split('/')
    hash.shift() if hash[0] == ''
    patt.shift() if patt[0] == ''
    return false if hash.length != patt.length
    args = [ ]
    for i in [0 .. patt.length - 1]
      if patt[i].charAt(0) == ':'
        args.push(hash[i])
        args[patt[i]] = hash[i]
      else if patt[i] != hash[i]
        return false

    @dispatchEvent new AppEvent 'routechange', { detail: @pattern, params: args }
    return true

  reload: ->
    @onHashChange()


class HashRouter extends Component
  constructor: (@parent, patterns) ->
    super
    @routes = [ ]
    if patterns
      for patt in patterns
        route = new Route(@, patt)
        @routes.push(route)

  reloadAll: ->
    for route in @routes
      route.reload()


class Presenter extends Component
  constructor: (@parent, view) ->
    super
    view ?= @view # fetch it from the prototype
    if typeof view == 'string'
      @view = document.getElementById(view)

  start: ->


class LocalStorage extends Component

  makeKey: (name, id) -> name + '.' + id
  readKey: (key) -> key.split('.', 2)

  insert: (type, data) ->
    id = UUID.generate()
    data.id = id
    key = @makeKey(type, id)
    Future.defer =>
      localStorage.setItem(key, JSON.stringify(data))
      @dispatchEvent new AppEvent "storage", { key: key, newValue: data, oldValue: null }
      return id

  update: (type, data) ->
    key = @makeKey(type, data.id)
    Future.defer =>
      val = localStorage.getItem(key)
      if val?
        localStorage.setItem(key, JSON.stringify(data))
        @dispatchEvent new AppEvent "storage", { key: key, newValue: data, oldValue: val }

  remove: (type, id) ->
    key = @makeKey(type, id)
    Future.defer =>
      val = localStorage.getItem(key)
      if val?
        localStorage.removeItem(key)
        @dispatchEvent new AppEvent "storage", { key: key, newValue: null, oldValue: val }

  find: (type, params={ }, from=0, size=10) ->
    Future.defer =>
      found = [ ]
      hasFilter = Object.keys(params).length > 0
      for i in [0 .. localStorage.length - 1]
        key  = localStorage.key(i)
        pair = @readKey(key)
        if pair[0] == type
          record = JSON.parse(localStorage.getItem(key))
          if hasFilter
            for k, v of params
              if k[0] == '!'
                if Array.isArray(record[k])
                  found.push(record) if record[k].indexOf(v) < 0
                else
                  found.push(record) if record[k] != v
              else
                if Array.isArray(record[k])
                  found.push(record) if record[k].indexOf(v) >= 0
                else
                  found.push(record) if record[k] == v
          else
            found.push(record)

      return found.slice(from, from + size)

  fetch: (type, id) ->
    Future.defer =>
      found = localStorage.getItem(@makeKey(type, id))
      if found?
        found.id = id
        return found
      return null


class ValidationError
  constructor: (field, message) ->
    @field   = field
    @message = message

  toString: ->
    "validation failed for field: #{@field}, reason: #{@message}"


class Schema

  regexEmail = ///^(
    ([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)
    |(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])
    |(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,})
  )$///

  constructor: (name, desc) ->
    desc = desc.call(@) if typeof desc == 'function'
    @name = name
    @properties = desc

  validate: (record) ->
    for key, desc of @properties
      @validateField(desc, key, record)
    record

  getDescriptor: (desc) ->
    if typeof desc == 'string'
      path = desc.split '.'
      desc = @properties
      for frag in path
        desc = desc[frag]
    desc

  validateField: (desc, key, obj) ->
    desc = @getDescriptor(desc)
    val = obj[key]
    if not val?
      if desc.default
        val = desc.default.call(@)
        obj[key] = val
      else if desc.required
        throw new Error "#{key} is required"
      else
        return null

    try
      @validateValue(desc, val)
    catch ex
      if typeof ex == 'string'
        throw new ValidationError key, "#{key} #{ex}"
      else
        throw ex

  validateValue: (desc, val) ->
    desc = @getDescriptor(desc)
    switch desc.type
      when "string"
        if typeof val != "string"
          throw "is not a string"

      when "boolean"
        if typeof val != "boolean"
          throw "is not a boolean"

      when "number"
        val = parseFloat(val) if typeof val == "string"
        if typeof val != "number" or val == NaN
          throw "is not a number"

      when "integer"
        val = parseInt(val) if typeof val == "string"
        if typeof val != "number" or val == NaN or Math.floor(val) != val
          throw "is not an integer"

      when "array"
        if Array.isArray(val)
          if desc.items
            for i in [0 .. val.length - 1]
              @validateField(desc.items, i, val)
        else
          throw "is not an array"

      when "object"
        if typeof val != "object"
          throw "is not an object"
        if desc.properties
          for k, d of desc.properties
            @validateField(d, k, val)

      when "date"
        if typeof val == "string"
          if not Moment(val, desc.format or 'YYYY-MM-DD').isValid()
            throw "is not a valid date"
        else if not val instanceof Date
          throw "is not a valid date"

      when "email"
        if not regexEmail.test(val)
          throw "is not a valid email address"

      when "pattern"
        rx = desc.pattern
        rx = new RegExp(rx) if typeof rx == "string"
        if not rx.test(val)
          throw "does not match '#{desc.pattern}'"

      when "enum"
        if not desc.values.contains(val)
          throw "is not one of #{desc.values.join(',')}"

      when "any"
        return
      else
        if desc.properties
          for k, d of desc.properties
            @validateField(d, k, val)
        else
          throw new Error "unknown type '#{desc.type}' in schema"

    return


class Model extends Component
  @schema = (name, desc) ->
    @::schema = new Schema name, desc

  constructor: (record = { }) ->
    super
    @schema.validate(record)
    @record = record

  get: (field) ->
    if not @schema.properties[field]
      throw new Error("no such field '#{field}' in schema '#{@schema.name}'")
    @record[field]

  set: (field, value) ->
    if not @schema.properties[field]
      throw new Error("no such field '#{field}' in schema '#{@schema.name}'")
    @record[field] = value
    @schema.validateField(@schema.properties[field], field, @record)

  toJSON: -> @record

  @fromForm: (form) ->
    patt = /\[|\]|\d+|[a-zA-Z_$][a-zA-Z0-9_$]*|\./g
    data = { }
    for elmt in form.elements
      name = elmt.name or elmt.id
      continue if not name

      if not expr = name.match(patt)
        throw new Error "malformed expression"

      desc = @::schema
      curr = data
      nest = 0
      key = null
      val = null
      pos = 0
      any = { type: "any" }

      while expr.length > 0
        tok = expr.shift()

        if tok.match /^\d+$/
          if nest != 1
            throw new Error "unexpected '#{tok}' at #{pos} in #{name}"
          key = parseInt(tok)

        else if tok.match /^[a-zA-Z_$][a-zA-Z0-9_$]*$/
          if nest == 1
            throw new Error "unexpected '#{tok}' at #{pos} in #{name}"
          key = tok

        else if tok == '['
          if nest != 0
            throw new Error "unexpected '[' at #{pos} in #{name}"
          if desc and desc.items
            desc = desc.items
          else
            desc = any
          curr[key] ?= [ ]
          curr = curr[key]
          key = null
          ++nest

        else if tok == ']'
          if nest != 1
            throw new Error "unexpected ']' at #{pos} in #{name}"
          if typeof key != "number"
            throw new Error "numeric key expected at #{pos} in #{name}"
          --nest

        else if tok == '.'
          if not key?
            throw new Error "unexpected '.' at #{pos} in #{name}"
          if desc
            desc = desc.properties[key] if typeof key == 'string'
          else
            desc = any
          curr[key] ?= { }
          curr = curr[key]
          key = null
        pos += tok.length

      switch elmt.nodeName
        when 'INPUT'
          if elmt.type == "checkbox" or elmt.type == "radio"
            val = elmt.value if elmt.checked
          else
            val = elmt.value
        when 'SELECT'
          if elmt.type == 'select-multiple'
            val = [ ]
            for opt in elmt.options
              if opt.selected
                val.push(opt.value)
          else
            val = elmt.value
        else
          val = elmt.value

      curr[key] = val
      @::schema.validateField(desc, key, curr)

    new @(data)


class Resource extends Model

  storage: ->
    if application.storage[name]?
      application.storage[name]
    else
      application.storage.default

  insert: ->
    @storage().insert(@schema.name, @toJSON())

  update: ->
    @storage().update(@schema.name, @toJSON())

  remove: ->
    @storage().remove(@schema.name, @record.id)

  @fetch: ->
    @::storage().fetch(@::schema.name, arguments...).andThen (record) =>
      return new @(record) if record?
      return null

  @find: ->
    @::storage().find(@::schema.name, arguments...).andThen (records) =>
      records.map (record) => new @(record)


class Application extends Component
  @::storage = { default: new LocalStorage() }
  constructor: (RootControl, @config = { })->
    super()
    self.application = this
    @root = new RootControl(@)
    @root.name = ""

  start: ->
    @root.start()


module.exports = {
  UUID
  Future
  Promise
  Route
  HashRouter
  HtmlBuilder
  UI
  HttpRequest
  WS
  UriTemplate
  Moment
  AppEvent
  Component
  Presenter
  Application
  LocalStorage
  Schema
  Model
  Resource
}

