path    = require 'path'
ep      = require 'event-pipe'
os      = require 'options-stream'
levels  = require './levels'
Log     = require './log'

{info, debug, warn, error} = levels

cwd = process.cwd()

defaultAccessLogFile = "
[#{cwd}/logs/#{path.basename (path.basename process.argv[1] , '.js'), '.coffee'}-access-]YYYY-MM-DD[.log]
"

logs = []
flushTime = 1000
timer = null

heartBeat = ->
  now = new Date().getTime()
  inst.heartBeat now for inst in logs
  timer = setTimeout ->
    heartBeat()
  , flushTime

heartBeat()


traceid = new Buffer 16
[v1, v2, v3] = process.version.substring(1).split('.')
if v1 * 100000 + v2 * 1000 + Number(v3) > 11013
  getTraceId = (req)->
    # +   ========   +      ====      +     ====     +
    # + random bytes + ip^(masek|pid) + request time +
    traceid.writeUInt32BE Math.random() * 4294967296
    traceid.writeUInt32BE Math.random() * 4294967296, 4
    [f1,f2,f3,f4] = req.socket.remoteAddress.split '.'
    ip = Number(f1) << 24 | (Number(f2) << 16) | (Number(f3) << 8) | Number(f4)
    ip ^= (Number(req.socket.remotePort) << 16) | process.pid
    traceid.writeInt32BE ip, 8
    traceid.writeUInt32BE req.__justLogStartTime/1000, 12
    traceid.toString 'base64'
else
  getTraceId = (req)->
    # +   ========   +      ====      +     ====     +
    # + random bytes + ip^(masek|pid) + request time +
    traceid.writeUInt32BE Math.random() * 4294967296, 0
    traceid.writeUInt32BE Math.random() * 4294967296, 4
    [f1,f2,f3,f4] = req.socket.remoteAddress.split '.'
    ip = Number(f1) << 24 | (Number(f2) << 16) | (Number(f3) << 8) | Number(f4)
    ip ^= (Number(req.socket.remotePort) << 16) | process.pid
    traceid.writeInt32BE ip, 8
    traceid.writeUInt32BE parseInt(req.__justLogStartTime/1000), 12
    traceid.toString 'base64'

factory =
  config : (opt)->
    flushTime = opt.flushTime if opt.flushTime
    clearTimeout timer if timer
    heartBeat()

  create : (options)->
    log = Log options
    logs.push log
    log

  end : (cb = ->)->
    fns = []
    fn = (inst)->
      ->
        inst.close @
    for inst in logs
      fns.push fn inst

    logs.length = 0
    pipe = ep()
    pipe.on 'error', cb
    pipe.lazy fns if fns.length
    pipe.lazy ->
      cb()
    pipe.run()

  ###
  /**
   * connect middleware
     * @param  {Object} options
     *  - {String} [encodeing='utf-8'],        log text encoding
     *  - file :
     *    - {Number} [level=error|warn],       file log levels
     *    - {String} [pattern='accesslog-rt'], log line pattern
     *    - {String} [mode='0664'],            log file mode
     *    - {String} [dir_mode='2775'],        log dir mode
     *    - {String} [path="[$CWD/logs/$MAIN_FILE_BASENAME-access-]YYYY-MM-DD[.log]"],   log file path pattern
     *  - stdio:
     *    - {Number}         [level=all],              file log levels
     *    - {String}         [pattern='accesslog-rt'], log line pattern
     *    - {WritableStream} [stdout=process.stdout],  info & debug output stream
     *    - {WritableStream} [stderr=process.stderr],  warn & error output stream
   * @param  {Function} cb(justlog)
   * @return {Middlewtr}
  ###
  middleware : (options) ->
    options = os
      file:
        path    : defaultAccessLogFile
        pattern : 'accesslog-rt'
      stdio:
        pattern : 'accesslog-color'
      traceid   : false
    , options
    # make sure level info need log
    options.file.level |= info
    options.stdio.level |= info
    # new log object
    log = Log options
    logs.push log
    # middleware
    mw = (req, resp, next) =>
      # response timer
      req.__justLogStartTime = new Date
      # hack resp.end
      end = resp.end
      resp.__justLogTraceId = req.__justLogTraceId = getTraceId(req) if options.traceid

      resp.end = (chunk, encoding) ->
        resp.end = end
        resp.end chunk, encoding
        log.info {
          'remote-address' : req.socket.remoteAddress
          'remote-port'    : req.socket.remotePort
          method           : req.method
          url              : req.originalUrl || req.url
          version          : req.httpVersionMajor + '.' + req.httpVersionMinor
          status           : resp.statusCode
          'content-length' : parseInt resp.getHeader('content-length'), 10
          headers          : req.headers
          rt               : new Date() - req.__justLogStartTime
          traceid          : req.__justLogTraceId
        }
      next()
    mw.justlog = log
    mw

create = (options)->
  log = new Log options
  logs.push log
  log
# set levels const
create[k.toUpperCase()] = v for k, v of levels.levels
# exports
module.exports = create

module.exports[k] = v for k, v of factory
