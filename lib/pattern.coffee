coffee = require 'coffee-script'
moment = require 'moment'
colors = require './colors'
path   = require 'path'
levels   = require './levels'

cwd = process.cwd()
reg = [
  /\b(file|lineno|stack|stackColored)\b/
  /\b(now|time|date|fulltime|numbertime|mstimestamp|timestamp|moment)\b/
  /\((.+?):(\d+):\d+\)$/]

timeFormats =
  time : 'HH:mm:ss'
  date : 'YYYY-MM-DD'
  fulltime : 'YYYY-MM-DD HH:mm:ss'
  numbertime : 'YYYYMMDDHHmmss'

justlogPath = __dirname + '/justlog' + path.extname __filename

module.exports =
  ###
  /**
   * pre-defined log patterns
   * @type {object}
   *  colored :
   *   - SIMPLE-COLOR: log message and colored level text
   *   - SIMPLE-NOCOLOR:  like simple without color
   *   - COLOR: tracestack, time, log message and colored level text
   *  nocolor :
   *   - NOCOLOR: like color without color
   *   - FILE : fulltime, tracestack, log message and level text
   *  connect-middleware : ()
   *   - ACCESSLOG: apache access-log
   *   - ACCESSLOG-RT: like access-log with response-time on the end (with microsecond)
   *   - ACCESSLOG-COLOR: like ACCESSLOG-RT with ansi colored
  ###
  pre :
    'SIMPLE-NOCOLOR' : '#{level} #{msg}'
    'SIMPLE-COLOR'   : '#{levelColored} #{msg}'
    'NOCOLOR'        : '#{time} [#{level.trim()}] (#{stack) #{msg}'
    'COLOR'          : '#{time} #{levelColored} #{stackColored} #{msg}'
    'FILE'           : '#{fulltime} [#{level.trim()}] (#{stack}) #{msg}'
    'ACCESSLOG' : '''
      #{removeAddr} #{ident} #{user}
      [#{now "DD/MMM/YYYY:HH:mm:ss ZZ"}]
      "#{method} #{url} HTTP/#{httpVersion}"
      #{statusCode} #{response.length}
      "#{headers.referer}"
      "#{headers["user-agent"]}"
    '''.replace /\n/g, ' '
    'ACCESSLOG-RT' : '''
      #{removeAddr} #{ident} #{user}
      [#{now "DD/MMM/YYYY:HH:mm:ss ZZ"}]
      "#{method} #{url} HTTP/#{httpVersion}"
      #{statusCode} #{response.length}
      "#{headers.referer}"
      "#{headers["user-agent"]}"
      #{response.time}
    '''.replace /\n/g, ' '
    'ACCESSLOG-COLOR' : '''
      #{removeAddrColored} #{ident} #{user}
      [#{now "DD/MMM/YYYY:HH:mm:ss ZZ"}]
      "#{methodColored} #{urlColored} HTTP/#{httpVersion}"
      #{statusCodeColored} #{response.length}
      "#{color:blue}#{headers.referer}#{color.reset}"
      "#{color:cyan}#{headers["user-agent"]#{color.reset}}"
      #{response.time}
    '''.replace /\n/g, ' '

  ###
  /**
   * compile log-format pattern to a render function
   * @param  {string} tpl  pattern string
   * @return {function}    pattern render function
   *  - {bool}   [trace]   need tracestack info
   *  - {bool}   [time]    need logtime info
   *  - {string} [pattern] pattern text
  ###
  compile : (pattern)->
    # wrapper
    code = coffee.compile('"' + pattern + '"', bare:true).trim()
    code = "with(__vars||{}){return #{code}}"
    func = new Function('__vars', code)
    func.stack   = reg[0].test pattern # need trace stack for get log position
    func.time    = reg[1].test pattern # need moment for time format
    func.pattern = pattern
    func

  ###
  /**
   * render one line
   * @param  {function} render attern render function (generate by .compile())
   * @param  {string]}  msg    log messages
   * @param  {string}   level  log level
   * @return {string}          log line text
  ###
  format : (render, msg, level) ->
    msg = '' if msg is null
    msg = msg: msg.toString() if typeof msg isnt 'object'
    msg.color        = colors
    msg.color.level  = levels.color[level]
    msg.level        = levels.text[level]
    msg.levelColored = "#{msg.color.level}#{msg.level}#{colors.reset}"
    if render.time
      now = moment()
      msg[k] = now.format v for k,v of timeFormats
      msg.now = now.format.bind now
      msg.mstimestamp = now.valueOf()
      msg.timestamp = Math.floor msg.mstimestamp / 1000
      msg.moment = moment
    if render.stack
      try
        throw new Error
      catch err
        stacks = err.stack.split "\n"
        flag = false
        for stack in stacks
          if res = stack.match reg[2]
            if res[1] isnt justlogPath and res[1] isnt __filename
              flag = true
              break
        if flag is false
          msg.file = 'NULL'
          msg.lineno = 0
        else
          file = res[1]
          msg.file = if file[0] is '/' then path.relative cwd, file else file
          msg.lineno = res[2]
        msg.stack = "#{msg.file}:#{msg.lineno}"
        msg.stackColored = "#{colors.underline}#{colors.cyan}#{msg.file}:#{colors.yellow}#{msg.lineno}#{colors.reset}"
    render(msg) + "\n"
