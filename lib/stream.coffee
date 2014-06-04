fs      = require 'fs'
path    = require 'path'
events  = require 'events'
os      = require 'options-stream'

class FileStream extends events.EventEmitter
  constructor : (options)->
    @options = os
      filePath : ''
      # duration : 1000
      bufferLength : 0
      mode     : '0664'
    , options

    @_buffer = []

    @_newStream()

  write : (str)->
    @_buffer.push str
    @flush() if @_buffer.length > @options.bufferLength

  end : ()->
    return unless @stream
    @_closeStream()

  _newStream : ->
    {filePath, mode} = @options

    stream = fs.createWriteStream filePath, flags: 'a', mode: mode
    stream.on 'error', @emit.bind @, 'error'
    stream.on 'open', @emit.bind @, 'open'
    stream.on 'close', @emit.bind @, 'close'
    @stream = stream

  _closeStream : ->
    @flush()
    @stream.end()
    @stream.destroySoon()
    @stream = null

  flush : ->
    return unless @_buffer.length
    @stream.write @_buffer.join ''
    @_buffer.length = 0

module.exports = (options)->
  new FileStream options
