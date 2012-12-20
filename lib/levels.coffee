colors = require './colors'
#levels define
info  = 1
debug = 2
warn  = 4
error = 8


text = {}
text[info]  = 'INFO '
text[debug] = 'DEBUG'
text[warn]  = 'WARN '
text[error] = 'ERROR'

#level color define
color = {}
color[info]  = colors.green
color[debug] = colors.cyan
color[warn]  = colors.yellow
color[error] = colors.red

module.exports =
  color  : color
  text   : text
  info   : info
  debug  : debug
  warn   : warn
  error  : error
  levels :
    info      : info
    debug     : debug
    warn      : warn
    error     : error
    all       : error | warn | debug | info # all level const
    exception : error | warn                # error levels const
