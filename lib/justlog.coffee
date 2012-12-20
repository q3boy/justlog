fs      = require 'fs'
path    = require 'path'
util    = require 'util'
events  = require 'events'
moment  = require 'moment'
mkdirp  = require 'mkdirp'
os      = require 'options-stream'
levels  = require './levels'
timeout = require './timeout'
pattern = require './pattern'

# lazy levels
{info, debug, warn, error} = levels

cwd = process.cwd()

# default log filename
defaultLogFile = "
[#{cwd}/logs/
#{path.basename (path.basename process.argv[1] , '.js'), '.coffee'}
-]YYYY-MM-DD[.log]
"

# log rotate minimum ms
MIN_ROTATE_MS = 100

###
/**
 * @name rename
 * @description log file is renamed
 * @event
 * @param {String} [file], filepath
###
###
/**
 * @name timer
 * @description a new rotate timer is set
 * @event
 * @param {Number} [ms], milliseconds for next rotate
###
###
/**
 * @name rotate
 * @description file rotated
 * @event
 * @param {string} [prev], old filepath
 * @param {string} [curr], new filepath
###
class JustLog extends events.EventEmitter

  ###
  /**
   * @param  {Object} options
   *  - {String} [encodeing='utf-8'],  log text encoding
   *  - file :
   *    - {Number} [level=error|warn], file log levels
   *    - {String} [pattern='file'],   log line pattern
   *    - {String} [mode='0664'],      log file mode
   *    - {String} [dir_mode='2775'],  log dir mode
   *    - {String} [path="[$CWD/logs/$MAIN_FILE_BASENAME-]YYYY-MM-DD[.log]"],   log file path pattern
   *  - stdio:
   *    - {Number}         [level=all],             file log levels
   *    - {String}         [pattern='color'],       log line pattern
   *    - {WritableStream} [stdout=process.stdout], info & debug output stream
   *    - {WritableStream} [stderr=process.stderr], warn & error output stream
  ###
  constructor : (options)->
    @options = os {
      encoding : 'utf-8'
      file : {
        level           : error | warn
        pattern         : 'file'
        path            : defaultLogFile
        mode            : '0664'
        dir_mode        : '2775'
        _watcher_timeout : 1000
      }
      stdio : {
        level   : error | warn | debug | info
        pattern : 'color'
        stdout  : process.stdout
        stderr  : process.stderr
      }
    }, options

    # options fix
    @options.file  = false if @options.file.level is 0
    @options.stdio = false if @options.stdio.level is 0

    # set level define as properties
    @[k.toUpperCase()] = v for k, v of levels.levels # levels const

    # file info init
    @file =
      path : null, stream : null, timer : null, opening : false
      watcher: null, ino: null

    @closed = false

    # need stdio
    if @options.stdio
      @stdout = @options.stdio.stdout
      @stderr = @options.stdio.stderr
      @options.stdio.render = pattern.compile pattern.pre[@options.stdio.pattern] ? @options.stdio.pattern

    # need file
    if @options.file
      @options.file.render = pattern.compile pattern.pre[@options.file.pattern] ? @options.file.pattern
      @_initFile()

  # overwrite emit
  emit : (args...)->
    super args...
    super 'all', args...
    return

  # check log file renamed
  _checkFileRenamed : (cb)->
    # check need file             has stream              stream opened
    if @options.file is false or @file.stream is null or @file.opening is true
      cb null, false
      return

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
      @emit 'rename', @file.path
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
      @file.ino = null
      @file.opening = false
    @file.stream = stream


  _closeStream : ->
    @file.stream.end() # end stream
    @file.stream.destroySoon() # destory after drain
    @file.stream = null # clear object
    return


  _initFile : ->
    # set file path
    @_setFilePath()
    @_newStream()
    @file.watcher = setInterval @_checkFile.bind(@), @options.file._watcher_timeout
    @_rotateFile()



  _rotateFile : ->
    [ms] = timeout @options.file.path # get next timeout (ms)
    return if null is ms # return if log file has no rotate rules

    # fix timeout <= MIN_ROTATE_MS
    ms = MIN_ROTATE_MS if ms <= MIN_ROTATE_MS
    # remove old timeout
    if @file.timer isnt null

      clearTimeout @timer
      @timer = null


    # set timeout
    @file.timer = setTimeout @_rotateFile.bind(@), ms
    process.nextTick =>
      @emit 'timer', ms # async emit 'timer-start'

    # check filepath changed
    prev = @file.path
    @_setFilePath()
    if prev isnt @file.path
      @_closeStream() # close old stream
      @_newStream() # make new stream
      @emit 'rotate', prev, @file.path
    return

  _fileLog : (msg, level) ->
    line = pattern.format @options.file.render, msg, level
    @file.stream.write line, @options.encoding

  _stdioLog : (msg, level) ->
    line = pattern.format @options.stdio.render, msg, level
    (if level & (error|warn) then @stderr else @stdout).write line, @options.encoding


  _log : (msg, level) ->
    msg = util.format msg...
    @_fileLog  msg, level if @options.file  && (@options.file.level  & level)
    @_stdioLog msg, level if @options.stdio && (@options.stdio.level & level)
    @

  ###
  /**
   * send an info log
   * @param  {Mixed} msg... log info (run as console.log)
   * @return {JustLog}      return self object for chain call
  ###
  info  : (msg...) -> @_log msg, info
  ###
  /**
   * send an debug log
   * @param  {Mixed} msg... log info (run as console.log)
   * @return {JustLog}      return self object for chain call
  ###
  debug : (msg...) -> @_log msg, debug
  ###
  /**
   * send an warn log
   * @param  {Mixed} msg... log info (run as console.log)
   * @return {JustLog}      return self object for chain call
  ###
  warn  : (msg...) -> @_log msg, warn
  ###
  /**
   * send an error log
   * @param  {Mixed} msg... log info (run as console.log)
   * @return {JustLog}      return self object for chain call
  ###
  error : (msg...) -> @_log msg, error

  ###
  /**
   * close log
   * @param  {Function} cb after close callback
  ###
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

create = (options) -> new JustLog options

create[k.toUpperCase()] = v for k, v of levels.levels # levels const
# create[k]               = v for k, v of pattern.pre   # pre-defined log format

module.exports = create
