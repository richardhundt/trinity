if Element = self.HTMLElement || self.Element
  if not 'classList' in document.documentElement
    class DOMError extends Error
      constructor: (@name, @message) ->
        @code = DOMException[@name]

    class ClassList extends Array
      constructor: (elem) ->
        trimmed = String::trim.call(elem.className)
        classes = if trimmed then trimmed.split(/\s+/) else [ ]
        @push(c) for c in classes

        @_updateClassName = ->
          elem.className = @toString()

      tokenIndexOf = (classList, token) ->
        if token is ""
          throw new DOMError("SYNTAX_ERR", "An invalid or illegal string was specified")
        if /\s/.test(token)
          throw new DOMError("INVALID_CHARACTER_ERR", "String contains an invalid character")
        Array::indexOf.call(classList, token)

      item: (i) ->
        @[i] || null

      contains: (token) ->
        token += ""
        return tokenIndexOf(@, token) != -1

      add: (tokens...) ->
        updated = false
        for token in tokens
          token += ""
          if tokenIndexOf(@, token) is -1
            @push(token);
            updated = true;

        @_updateClassName() if updated

      remove: (tokens...) ->
        updated = false
        for i in [0 .. tokens.length - 1]
          token = tokens[i] + ""
          if tokenIndexOf(@, token) != -1
            @splice(index, 1)
            updated = true;

        @_updateClassName() if updated

      toggle: (token, force) ->
        token += ""
        found = @contains(token)
        if found
          if force != true
            @remove(token)
          else if force != false
            @add(token)
        !found

      toString: -> @join(" ")

    if Object.defineProperty
      desc = {
        get: ->
          new ClassList(@)
        enumerable: true
        configurable: true
      }
      try
        Object.defineProperty(Element::, "classList", desc)
      catch ex
        if ex.number is -0x7FF5EC54
          desc.enumerable = false;
          Object.defineProperty(Element::, "classList", desc)
    else if Object::__defineGetter__
      Element::__defineGetter__("classList", -> new ClassList(@))


  if !Element::matchesSelector
    Element::matchesSelector =
      Element::matches ||
      Element::webkitMatchesSelector ||
      Element::mozMatchesSelector ||
      Element::msMatchesSelector ||
      Element::oMatchesSelector || (selector) ->
        if !selector then return false
        if selector is "*" then return true
        if this is document.documentElement && selector is ":root"
          return true
        if this is document.body && selector is "body"
          return true
   
        match = false
   
        if /^[\w#\.][\w-]*$/.test(selector) || /^(\.[\w-]*)+$/.test(selector)
          switch selector.charAt(0)
            when '#'
              return this.id is selector.slice(1)
            when '.'
              match = true
              i = -1
              tmp = selector.slice(1).split(".")
              str = " " + this.className + " "
              while tmp[++i] and match
                match = str.indexOf(" " + tmp[i] + " ") > 0
              return match
            else
              return this.tagName && this.tagName.toUpperCase() is selector.toUpperCase()

        parent = this.parentNode
        
        if parent and parent.querySelector
          match = parent.querySelector(selector) is this
   
        if !match && (parent = this.ownerDocument)
          tmp = parent.querySelectorAll(selector)
          for own i of tmp
            match = tmp[i] == this
            if match then return true
          return match

