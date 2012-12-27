root = window.mit ?= {}
window.console ?=
    log: ->
root.logfunc = (name) -> ->
    console.log name, @, arguments

