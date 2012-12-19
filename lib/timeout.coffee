reg = /\[.*?\]/g
rules =
  second : /s{1,2}/
  minute : /m{1,2}/
  hour   : /(h{1,2}|a)/i
  day    : /d{1,4}/i
  month  : /M{1,4}/
  year   : /(YY|YYYY)/


# get timeout ms
module.exports = (pattern) ->
  clean = pattern.replace reg, ''
  for name, rule of rules
    if rule.test clean
      type = name
      break
  n = new Date
  switch type
    when 'second'
      ms = new Date(n.getFullYear(), n.getMonth(), n.getDate(), n.getHours(), n.getMinutes(), n.getSeconds() + 1) - n
    when 'minute'
      ms = new Date(n.getFullYear(), n.getMonth(), n.getDate(), n.getHours(), n.getMinutes() + 1) - n
    when 'hour'
      ms = new Date(n.getFullYear(), n.getMonth(), n.getDate(), n.getHours() + 1) - n
    when 'day'
      ms = new Date(n.getFullYear(), n.getMonth(), n.getDate() + 1) - n
    when 'month'
      ms = new Date(n.getFullYear(), n.getMonth() + 1, 1) - n
    when 'year'
      ms = new Date(n.getFullYear() + 1, 0, 1) - n
    else
      ms = null
  [ms, type]
