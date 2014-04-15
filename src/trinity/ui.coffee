{UI, HtmlBuilder, Component, AppEvent, Moment} = require("trinity")

class UIComponent extends Component
  ID_SEQ = 0
  constructor: (@parent, view, args...) ->
    super
    if typeof view == 'function'
      @view = UI.build(view)
    else if typeof view == 'string'
      @view = document.getElementById(view)
    else if view
      @view = view
    else
      @view = document.createElement('div')

    @view.id ||= "_" + (ID_SEQ++)
    UI.buildOn(@view, @buildAll, args...)

  buildAll: (args...) => @build(args...)

  build: (_) ->


class UIDeck extends UIComponent
  showItemAt: (index) ->
    items = @view.querySelectorAll(".collapse")
    for i in [0..items.length - 1]
      if i == index
        items[i].classList.add('in')
      else
        items[i].classList.remove('in')

    @dispatchEvent new AppEvent "deckchange", { detail: index }


class UINav extends UIComponent
  setActiveAt: (index) ->
    items = @view.querySelectorAll(".nav-item")
    for i in [0..items.length - 1]
      if i == index
        items[i].classList.add("active")
      else
        items[i].classList.remove("active")

    @dispatchEvent new AppEvent "navchange", { detail: index }


class UIDropdown extends UIComponent

  build: ->
    @menu = new UIDropdownMenu(@, @view.querySelector('.dropdown-menu'))
    @toggleSelector = "##{@view.id} > .dropdown-toggle"
    @caretSelector  = @toggleSelector + " .caret"
    @view.addEventListener "click", @handleViewEvent

  handleViewEvent: (evt) =>
    tgt = evt.target
    tgt = tgt.parentNode if tgt.matchesSelector(@caretSelector)
    if tgt.matchesSelector(@toggleSelector)
      @toggle()

  toggle: ->
    open = @view.classList.toggle("open")
    @dispatchEvent new AppEvent("toggle", { detail: open })

  hide: ->
    @view.classList.remove("open")
    @dispatchEvent new AppEvent("close", { detail: false })


class UIDropdownMenu extends UIComponent
  build: ->
    @view.addEventListener "click", @handleViewEvent

  handleViewEvent: (evt) =>
    tgt = evt.target
    tgt = tgt.parentNode while tgt and tgt.parentNode != evt.currentTarget
    if tgt
      idx = Array::indexOf.call(@view.childNodes, tgt)
      @dispatchEvent new AppEvent("action", { detail: idx })


class UIDropdownToggle extends UIComponent

class UIAccordion extends UIComponent
  constructor: ->
    super
    @transitioning = false

  build: (_) ->
    toggles = @view.querySelectorAll('.accordion-toggle')
    for a in toggles
      a.addEventListener "click", @toggleViewHandler

  hide: (pane) ->
    pane.classList.remove('collapse')
    pane.style.height = pane.offsetHeight + 'px'
    window.setTimeout () ->
      pane.classList.add('collapsing')
      pane.style.height = '0px'
    , 0
    window.setTimeout (ctx) ->
      pane.classList.remove('collapsing')
      pane.classList.remove('in')
      pane.classList.add('collapse')
      pane.style.height = 'auto'
      ctx.transitioning = false
    , 350, @

  show: (pane) ->
    console.log('show pane')
    pane.classList.remove('collapse')
    pane.classList.add('collapsing')
    pane.style.height = pane.scrollHeight + 'px'
    window.setTimeout (ctx) ->
      pane.classList.remove('collapsing')
      pane.classList.add('collapse')
      pane.classList.add('in')
      pane.style.height = 'auto'
      ctx.transitioning = false
    , 350, @

  toggleViewHandler: (evt) =>
    if @transitioning then return
    @transitioning = true
    href = evt.target.getAttribute("href")
    curr = @view.querySelector(href)
    panes = @view.querySelectorAll('.collapse')

    for pane in panes
      if pane == curr
        if pane.classList.contains('in')
          @hide(pane)
        else
          @show(pane)
      else if pane.classList.contains('in')
        @hide(pane)
    evt.preventDefault()


class UIDatePicker extends UIComponent

  days   = ["Su","Mo","Tu","We","Th","Fr","Sa"]
  months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

  build: (_) ->
    @menu = @buildMenu(_)
    @menu.addEventListener "click", @handleMenuEvent
    @setDate(new Date())

  show: (what='days') ->
    for div in @menu.childNodes
      if div.classList.contains("datepicker-#{what}")
        div.classList.add('in')
      else
        div.classList.remove('in')
    @menu.classList.add('in')

  hide: ->
    @menu.classList.remove('in')

  toggle: ->
    if @menu.classList.contains('in')
      @hide()
    else
      @show()

  showDays:   -> @show('days')
  showMonths: -> @show('months')
  showYears:  -> @show('years')

  buildMenu: (_) ->
    _.div class:"datepicker dropdown-menu collapse", =>
      @buildDays(_)
      @buildMonths(_)
      @buildYears(_)

  buildDays: (_) ->
    _.div class:"datepicker-days collapse", ->
      _.table class:"table-condensed", ->
        _.thead ->
          _.tr ->
            _.th class:"prev", -> _.entity "lsaquo"
            _.th class:"switch", colspan:"5", -> _.text ""
            _.th class:"next", -> _.entity "rsaquo"
          _.tr ->
            for day in days
              _.th class:"dow", -> _.text day
        _.tbody ->
          for i in [1 .. 6]
            _.tr ->
              for j in [1 .. 7]
                _.td class:"day", -> _.text ""

  buildMonths: (_) ->
    _.div class:"datepicker-months collapse", ->
      _.table class:"table-condensed", ->
        _.thead ->
          _.tr ->
            _.th class:"prev", -> _.entity "lsaquo"
            _.th class:"switch", colspan:"5", -> _.text ""
            _.th class:"next", -> _.entity "rsaquo"
        _.tbody ->
          _.tr ->
            _.td colspan:"7", ->
              for month in months
                _.span class:"month", -> _.text month

  buildYears: (_) ->
    _.div class:"datepicker-years collapse", ->
      _.table class:"table-condensed", ->
        _.thead ->
          _.tr ->
            _.th class:"prev", -> _.entity "lsaquo"
            _.th class:"switch", colspan:"5", -> _.text ""
            _.th class:"next", -> _.entity "rsaquo"
        _.tbody ->
          _.tr ->
            _.td colspan:"7", ->
              _.span class:"year old", -> _.text ""
              for i in [1..10]
                _.span class:"year", -> _.text ""
              _.span class:"year old", -> _.text ""

  setDate: (date) ->
    @date = new Moment(date)
    @refresh()
    return @

  refresh: ->
    @setDateDays(@date)
    @setDateMonths(@date)
    @setDateYears(@date)

  handleMenuEvent: (evt) =>
    n = evt.target
    if n.matchesSelector(".datepicker-days *")
      @handleDaysViewEvent(n, evt)
    else if n.matchesSelector(".datepicker-months *")
      @handleMonthsViewEvent(n, evt)
    else if n.matchesSelector(".datepicker-years *")
      @handleYearsViewEvent(n, evt)

  handleDaysViewEvent: (n) ->
    if n.matchesSelector("thead th")
      if n.classList.contains("prev")
        @date.subtract('month', 1)
        @refresh()
      else if n.classList.contains("next")
        @date.add('month', 1)
        @refresh()
      else if n.classList.contains("switch")
        @showMonths()
    else if n.matchesSelector("tbody .day")
      d = parseInt(n.firstChild.nodeValue)
      if n.classList.contains("old")
        @date.subtract('month', 1)
      else if n.classList.contains("new")
        @date.add('month', 1)
      @date.date(d)
      @refresh()
      @dispatchEvent new AppEvent "change", { detail: @date.toDate() }

  handleMonthsViewEvent: (n) ->
    if n.matchesSelector("thead th")
      if n.classList.contains("prev")
        @date.subtract('year', 1)
        @refresh()
      else if n.classList.contains("next")
        @date.add('year', 1)
        @refresh()
      else if n.classList.contains("switch")
        @showYears()
    else if n.matchesSelector("tbody .month")
      m = months.indexOf(n.firstChild.nodeValue)
      @date.month(m)
      @refresh()
      @showDays()

  handleYearsViewEvent: (n) ->
    if n.matchesSelector("thead th")
      if n.classList.contains("prev")
        @date.subtract('year', 10)
        @refresh()
      else if n.classList.contains("next")
        @date.add('year', 10)
        @refresh()
      else if n.classList.contains("switch")
        @showMonths()
    else if n.matchesSelector("tbody .year")
      y = parseInt(n.firstChild.nodeValue)
      @date.year(y)
      @refresh()
      @showMonths()

  setDateDays: (date) ->
    cells = @menu.querySelectorAll('.datepicker-days td')
    c = new Moment(date)
    m = c.month()
    o = c.date(1).weekday()
    c.subtract('day', o + 1)
    for n in [0 .. cells.length - 1]
      d = n - o + 1
      c.add('day', 1)
      td = cells[n]
      td.className = "day"
      td.firstChild.nodeValue = c.date()
      if d <= 0
        td.classList.add("old")
      else if d > c.daysInMonth()
        td.classList.add("new")
      else if d == date.date()
        td.classList.add("active")

    head = @menu.querySelector(".datepicker-days th.switch")
    head.firstChild.nodeValue = @date.format('MMMM YYYY')

  setDateMonths: (date) ->
    cells = @menu.querySelectorAll('.datepicker-months span')
    for n in [0 .. cells.length - 1]
      if n == date.month()
        cells[n].classList.add("active")
      else
        cells[n].classList.remove("active")

    head = @menu.querySelector(".datepicker-months th.switch")
    head.firstChild.nodeValue = date.format('YYYY')

  setDateYears: (date) ->
    cells = @menu.querySelectorAll('.datepicker-years span')
    y = date.year()
    m = (y - (y % 10)) - 1
    for n in [0 .. cells.length - 1]
      cells[n].firstChild.nodeValue = m + n
      if m + n == y
        cells[n].classList.add("active")
      else
        cells[n].classList.remove("active")

    head = @menu.querySelector(".datepicker-years th.switch")
    head.firstChild.nodeValue = "#{m + 1}-#{m + 12}"


class UIForm extends UIComponent
  constructor: ->
    super
    @view.addEventListener 'submit', @submitEventHandler

  setData: (data) ->
    for elmt in @view.elements
      key = elmt.name || elmt.id
      continue if key == ""
      if data[key] != null
        switch elmt.nodeName 
          when "INPUT"
            if elmt.type == "checkbox" or elmt.type == "radio"
              elmt.checked = true
            else
              elmt.value = data[key].shift()
          when "SELECT"
            list = data[key].shift()
            for opt in elmt.options
              opt.selected = true if list.contains(opt.value)
          else
            item.value = data[key].shift()
    return

  _setDataValue = (data, key, val) ->
    if Array.isArray(data[key])
      data[key].push(val)
    else if data[key]?
      data[key] = [ data[key], val ]
    else if val != ""
      data[key] = val

  getData: ->
    data = { }
    for elmt in @view.elements
      key = elmt.name || elmt.id
      continue if key == ""
      switch elmt.nodeName
        when "INPUT"
          if elmt.type == "checkbox" or elmt.type == "radio"
            _setDataValue(data, key, elmt.value) if elmt.checked
          else
            _setDataValue(data, key, elmt.value)
        when "SELECT"
          if elmt.type == 'select-multiple'
            list = [ ]
            for opt in elmt.options
              if opt.selected
                list.push(opt.value)
            _setDataValue(data, key, list)
          else
            _setDataValue(data, key, elmt.value)
        else
          _setDataValue(data, key, elmt.value)
    data

  regexEmail = ///^(
    ([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)
    |(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])
    |(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,})
  )$///

  validate: ->
    errors = [ ]
    for elmt in @view.querySelector('form').elements
      if elmt.getAttribute("required")
        if elmt.value == ""
          errors.push(elmt)
          continue
      switch elmt.getAttribute("data-type")
        when "number"
          if not /^[+-]?\d+(\.\d+)?$/.test(elmt.value)
            errors.push(elmt)
        when "date"
          if not Moment(elmt.value).isValid()
            errors.push(elmt)
        when "email"
          if not regexEmail.test(elmt.value)
            errors.push(elmt)
    for elmt in errors
      elmt.parentNode.classList.add("has-error")
    return errors.length == 0

  submitEventHandler: (evt) =>
    evt.preventDefault()
    if @validate()
      @dispatchEvent new AppEvent "submit", { data: @getData() }


###
<ul class="tree-list">
  <li class="tree-item">
    <a href="#" class="tree-label">Item 1</a>
    <ul class="tree-list">
      <li class="tree-item">
        <a href="#" class="tree-label">Item 1.1</a>
      </li>
    </ul>
  </li>
</ul>
###
class UITreeItem extends UIComponent
  constructor: ->
    super
    @view.addEventListener "click", @clickHandler

  clickHandler: (ev) =>
    @view.classList.toggle("open")

  build: (_) ->
    for n in @view.querySelectorAll('.tree-list')
      new UITreeList(@, n)
    for n in @view.querySelectorAll('.tree-item')
      new UITreeItem(@, n)

class UITreeList extends UIComponent
  constructor: ->
    super


module.exports = {
  UI
  UIComponent
  UINav
  UIDeck
  UIDropdown
  UIDropdownMenu
  UIDropdownToggle
  UIAccordion
  UIDatePicker
  UIForm
  UITreeList
}

