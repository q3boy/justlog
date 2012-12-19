moment  = require 'moment'
fs      = require 'fs'
path    = require 'path'
events  = require 'events'
mkdirp  = require 'mkdirp'
os      = require 'options-stream'
util    = require 'util'
levels  = require './levels'
timeout = require './timeout'
pattern = require './pattern'

{info, debug, warn, error} = levels

cwd = process.cwd()

# default log filename
defaultLogFile = "
[#{cwd}/logs/
#{path.basename (path.basename process.argv[1] , '.js'), '.coffee'}
-]YYYY-MM-DD[.log]
"
MIN_ROTATE_TIMEOUT = 100
# console.log patterns
class JustLog extends events.EventEmitter

  constructor : (options)->
    @options = os {
      encoding : 'utf-8'
      file : {
        level           : error | warn
        pattern         : pattern.pre.FILE
        path            : defaultLogFile
        mode            : '0664'
        dir_mode        : '2775'
        watcher_timeout : 1000
      }
      stdio : {
        level   : error | warn | debug | info
        pattern : pattern.pre.COLOR
        stdout  : process.stdout
        stderr  : process.stderr
      }
    }, options

    # options fix
    @options.file  = false if @options.file.level is 0
    @options.stdio = false if @options.stdio.level is 0

    @file =
      path : null, stream : null, timer : null, opening : false
      watcher: null, ino: null

    @closed = false

    # need stdio
    if @options.stdio
      @stdout = @options.stdio.stdout
      @stderr = @options.stdio.stderr
      @options.stdio.render = pattern.compile @options.stdio.pattern

    # need file
    if @options.file
      @options.file.render  = pattern.compile @options.file.pattern
      @_initFile()

  # overwrite emit
  emit : (args...)->
    super args...
    super 'all', args...
    return

  # check log file renamed
  _checkFileRenamed : (cb)->
    # check    need file                 has stream              stream opened
    return if @options.file is false or @file.stream is null or @file.opening is true

    # get file stat
    fs.stat @file.path, (err, stat) =>
      # stat error
      if err
        if err.code is 'ENOENT' # file not exists, renamed
          cb null, true
        else # other error
          cb err
        return

      prev = @file.ino     # save prev inode
      @file.ino = stat.ino # set curr ino

      if prev is null or prev is stat.ino # first stat or inode unchanged
        cb null, false
      else # inode changed
        cb null, true
      return

  _checkFile : ->
    @_checkFileRenamed (err, changed)=>
      return @emit err if err

      return if changed is false
      @_closeStream() # close prev stream
      @_newStream() # open new stream
      return
    return

  _setFilePath : ->
    filePath = path.normalize moment().format @options.file.path
    filePath = path.relative cwd, filePath if path[0] is '/'
    @file.path = filePath

  _newStream : ->
    filePath = @file.path
    # mkdir
    try
      mkdirp.sync path.dirname(filePath), @options.file.dir_mode
    catch err
      @emit 'error', err
    # open flag
    @file.opening = true

    # open new stream
    stream = fs.createWriteStream filePath, flags: 'a', mode: @options.file.mode
    stream.on 'error', @emit.bind @ # on error
    stream.on 'open', => # opened
      @file.opening = false
    # stream.on 'close', => # closed
    @file.stream = stream


  _closeStream : ->
    return if @options.file is false or not @file.stream
    @file.stream.end() # end stream
    @file.stream.destroySoon() # destory after drain
    @file.stream = null # clear object
    return


  _initFile : ->
    return if not @options.file # if file closed
    # set file path
    @_setFilePath()
    @_newStream()
    @file.watcher = setInterval @_checkFile.bind(@), @options.file.watcher_timeout



  _rotateFile : ->
    [ms] = timeout @options.file.path # get next timeout (ms)
    return if null is ms # return if log file has no rotate rules

    # fix timeout <= MIN_ROTATE_TIMEOUT
    ms = MIN_ROTATE_TIMEOUT if ms <= MIN_ROTATE_TIMEOUT

    # remove old timeout
    if @file.timer isnt null
      clearTimeout @timer
      @timer = null

    # set timeout
    @file.timer = setTimeout @_rotateFile.bind(@), ms
    @emit 'timer-start', ms # emit 'timer-start'

    # check filepath changed
    prev = @file.path
    @_setFilePath()
    if prev isnt @file.path
      @_closeStream() # close old stream
      @_newStream() # make new stream
    return



  # _initFile : ->
  #   console.log 'init'
  #   return if not @options.file
  #   # set timer
  #   [ms] = timeout @options.file.path
  #   # console.log ms, @options.file
  #   if null isnt ms
  #     ms = 100 if ms <= 0
  #     if @timer isnt null
  #       clearTimeout @timer
  #       @timer = null

  #     @timer = setTimeout @_initFile.bind(@), ms
  #     @emit 'timer_start', ms

  #   # make path
  #   filePath = path.normalize moment().format @options.file.path
  #   filePath = path.relative cwd, filePath if path[0] is '/'
  #   # console.log filePath
  #   # return
  #   # skip if path hasn't changed
  #   return if @file.path is filePath

  #   # if has last stream
  #   if @file.stream
  #     @file.stream.end()
  #     @file.stream.destroySoon()
  #     @file.stream = null

  #   # mkdir
  #   try
  #     mkdirp.sync path.dirname(filePath), '2775'
  #   catch err
  #     @emit 'error', err

  #   # open flag
  #   @file.opening = true

  #   # open new stream
  #   # console.log filePath
  #   stream = fs.createWriteStream filePath,
  #     flags: 'a', mode: @options.file.mode

  #   # events pass
  #   emit = @emit.bind @
  #   stream.on('error', emit)
  #   .on('pipe', emit)
  #   .on('drain', emit)
  #   .on('open', =>
  #     @file.opening = false
  #     @file.watcher = setTimeout @_checkFile().bind(@), 1000
  #   )
  #   .on('close', => @emit '_close' if not @file.opening)

  #   @file.path   = filePath
  #   @file.stream = stream


  _fileLog : (msg, level) ->
    line = pattern.format @options.file.render, msg, level
    # console.log @file.stream;
    @file.stream.write line, @options.encoding

  _stdioLog : (msg, level) ->
    line = pattern.format @options.stdio.render, msg, level
    # console.log line
    (if level & (error|warn) then @stderr else @stdout).write line, @options.encoding


  _log : (msg, level) ->
    msg = util.format msg...
    @_fileLog  msg, level if @options.file  && (@options.file.level  & level)
    @_stdioLog msg, level if @options.stdio && (@options.stdio.level & level)
    @

  info  : (msg...) -> @_log msg, info
  debug : (msg...) -> @_log msg, debug
  warn  : (msg...) -> @_log msg, warn
  error : (msg...) -> @_log msg, error

  close : (cb) ->
    if @options.file is false or @closed
      process.nextTick cb if cb
      return
    @closed = true
    @file.stream.on 'close', cb if cb and @file.stream
    @_closeStream()
    if @file.watcher
      clearInterval @file.watcher
      @file.watcher = null
    if @file.timer
      clearTimeout @file.timer
      @file.timer = null
    return


create = (options)->
  new JustLog options

create.ERROR     = error
create.WARN      = warn
create.DEBUG     = debug
create.INFO      = info

create[k.toUpperCase()] = v for k,v of levels.levels
create[k] = v for k,v of pattern.pre

create.ALL       = error | warn | debug | info
create.EXCEPTION = error | warn


module.exports   = create

# a = new JustLog
# a.on 'all', (args...)->
#   console.log args
# require('http').createServer((req, resp)->console.log req).listen(8888)
