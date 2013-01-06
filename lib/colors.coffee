# ansi colors
levels = require './levels'
esc = '\x1B['

Colors =
  black      : esc + '30m', bg_black   : esc + '40m'
  red        : esc + '31m', bg_red     : esc + '41m'
  green      : esc + '32m', bg_green   : esc + '42m'
  yellow     : esc + '33m', bg_yellow  : esc + '43m'
  blue       : esc + '34m', bg_blue    : esc + '44m'
  magenta    : esc + '35m', bg_magenta : esc + '45m'
  cyan       : esc + '36m', bg_cyan    : esc + '46m'
  white      : esc + '37m', bg_white   : esc + '47m'
  reset      : esc + '0m'
  bold       : esc + '1m'
  underline  : esc + '4m'
  status : (status) ->
    for k,c of statusColors
      break if status >= k
    c + status + Colors.reset
  method : (method) ->
    (methodColors[method] ? Colors.yellow) + method + Colors.reset
  event : (event) ->
    (eventColors[event] ? Colors.green) + event + Colors.reset
  level : (level) ->
    (levelColors[level] ? Colors.green) + level + Colors.reset


module.exports = Colors
eventColors = {
  'error' : Colors.red
}
levelColors =
  'INFO ' : Colors.green
  'DEBUG' : Colors.cyan
  'WARN ' : Colors.yellow
  'ERROR' : Colors.red

methodColors = {
  GET    : Colors.green
  POST   : Colors.cyan
  PUT    : Colors.cyan
  DELETE : Colors.red
}
statusColors = {
  500 : Colors.red
  400 : Colors.yellow
  300 : Colors.cyan
  _   : Colors.green
}
