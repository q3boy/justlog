# coffee = require 'coffee-script'
moment = require 'moment'
colors = require './colors'
path   = require 'path'
levels   = require './levels'

cwd = process.cwd()
reg = [
  /\b(file|lineno|stack|stackColored)\b/
  /\b(now|time|date|fulltime|numbertime|mstimestamp|timestamp|moment)\b/
  /\(([^\)\(]+?):(\d+):\d+\)$/]
stackNames = ['file', 'lineno', 'stack', 'stackColored']
timeNames = ['now', 'time', 'date', 'fulltime', 'numbertime', 'mstimestamp', 'timestamp']

timeFormats =
  time : 'HH:mm:ss'
  date : 'YYYY-MM-DD'
  fulltime : 'YYYY-MM-DD HH:mm:ss'
  numbertime : 'YYYYMMDDHHmmss'

justlogPath = __dirname + '/log' + path.extname __filename

anonymous = '<anonymous>'

module.exports = pattern =
  ###
  /**
   * pre-defined log patterns
   * @type {object}
   *  colored :
   *   - simple-color: log message and colored level text
   *   - simple-nocolor:  like simple without color
   *   - color: tracestack, time, log message and colored level text
   *  nocolor :
   *   - nocolor: like color without color
   *   - event-color: time, log message and colored event
   *  nocolor :
   *   - event-nocolor: like event-color without color
   *   - file : fulltime, tracestack, log message and level text
   *  connect-middleware : ()
   *   - accesslog: apache access-log
   *   - accesslog-rt: like access-log with response-time on the end (with microsecond)
   *   - accesslog-color: like ACCESSLOG-RT with ansi colored
  ###
  pre :
    'simple-nocolor' : '{level} {msg}'
    'simple-color'   : '{color.level level} {msg}'
    'nocolor'        : '{time} [{levelTrim}] ({stack}) {msg}'
    'color'          : '{time} {color.level level} {stackColored} {msg}'
    'file'           : '{fulltime} [{levelTrim}] ({stack}) {msg}'
    'event-color'    : '{time} {color.event event} {args}'
    'event-nocolor'  : '{fulltime} {event} {args}'
    'accesslog' : '''
      {remote-address} {ident} {user}
      [{now "DD/MMM/YYYY:HH:mm:ss ZZ"}]
      "{method} {url} HTTP/{version}"
      {status} {content-length}
      "{headers.referer}" "{headers.user-agent}"
    '''.replace /\n/g, ' '
    'accesslog-rt' : '''
      {remote-address} {ident} {user}
      [{now 'DD/MMM/YYYY:HH:mm:ss ZZ'}]
      "{method} {url} HTTP/{version}"
      {status} {content-length}
      "{headers.referer}" "{headers.user-agent}" {rt}
    '''.replace /\n/g, ' '
    'accesslog-color' : '''
      {remote-address@yellow} {ident} {user}
      [{now 'DD/MMM/YYYY:HH:mm:ss ZZ'}]
      "{color.method method} {url@underline,bold,blue} HTTP/{version}"
      {color.status status} {content-length}
      "{headers.referer@blue}" "{headers.user-agent@cyan}" {rt}
    '''.replace /\n/g, ' '

  ###
  /**
   * compile log-format pattern to a render function
   * @param  {string} code pattern string
   * @return {function}    pattern render function
   *  - {bool}   [trace]   need tracestack info
   *  - {bool}   [time]    need logtime info
   *  - {string} [pattern] pattern text
  ###
  compile : (pat)->
    code = pattern.pre[pat] ? pat # check perdefines
    code = code.replace /"/g, '\\"' # slash '"'
    useStack = false
    useTime = false
    # match all tokens
    funcs = []
    code = code.replace ///
      \{
      ([a-zA-Z][\-\w]+)      # var name
      (?:\.([\w\-]+))?       # sub key name
      (?:\s([^}@]+?))?       # function args
      (?:@((?:[a-z_]+,?)+))? # style
      \}
    ///g, (match, name, key, args, style) ->
      useStack = true if name in stackNames # need tracestack
      useTime = true if name in timeNames   # need time
      codes = []

      # push style block
      code = ''
      styles = style.split ',' if style
      if styles
        code += colors[style] for style in styles
        codes.push '"' + code + '"'

      # push vars block
      code = ''
      if args # is function
        num = funcs.length
        funcs.push [name, key, args.replace(/\\"/g, '"')]
        code = "__func[#{num}]"
      else # is vars
        code += "__vars['#{name}']#{if key then "['#{key}']" else ''}"
      codes.push '(' + code + '||"-")'

      # push style reset block
      codes.push '"' + colors.reset + '"' if styles
      '"+\n' + codes.join('+\n') + '+\n"'

    # remove empty string
    code = ('"' + code + '"').replace(/^""\+$/mg, '')
    code = "return #{code.trim()};"

    # __func prefix
    funcCode = []
    if funcs.length > 0
      funcCode.push 'var __func = [];with(__vars||{}){'
      for [name, key, args] in funcs
        funcCode.push "__func.push(__vars['#{name}']#{if key then "['#{key}']" else ''}(#{args}));"
      funcCode.push '}'
    code = funcCode.join(";\n")+code

    # make function
    func = new Function('__vars', code)
    func.stack   = useStack # need trace stack for get log position
    func.time    = useTime # need moment for time format
    func.pattern = pat
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
    msg.level        = levels.text[level]
    msg.levelTrim    = msg.level.trim()
    if render.time
      now = moment()
      msg[k] = now.format v for k,v of timeFormats
      msg.now = now.format.bind now
      msg.mstimestamp = now.valueOf()
      msg.timestamp = Math.floor msg.mstimestamp / 1000
    if render.stack
      try
        throw new Error
      catch err
        stacks = err.stack.split "\n"
        flag = false
        for stack in stacks
          if res = stack.match reg[2]
            if res[1] isnt justlogPath and res[1] isnt __filename and res[1] isnt anonymous
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

