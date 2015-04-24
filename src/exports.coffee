Pickle = require './pickle'

module.exports =
  createEmpty: ->
    new Pickle

  createFromBuffer: (buffer) ->
    new Pickle(buffer)
