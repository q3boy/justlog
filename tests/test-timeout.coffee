#mocha
e = require 'expect.js'

describe 'Timeout calculate', ->
  timeout = require '../lib/timeout'
  args = now = null
  beforeEach ()->
    now = new Date
    args = [
      now.getFullYear(), now.getMonth(), now.getDate(),
      now.getHours(),
      now.getMinutes(), now.getSeconds()
    ]
  test = (pattern, argsNum, type) ->
    [ms, tp] = timeout pattern
    ++args[argsNum - 1]
    args = args[0...argsNum]
    args.push 0 for i in [args.length...3]
    args[3] = (args[3] ? 0) + (if argsNum < 3 then 24 else 0) + now.getTimezoneOffset() / 60
    next = new Date Date.UTC.apply {}, args
    myMs = next.valueOf() - now.valueOf()
    e(tp).to.be type
    e(myMs).to.be.below ms + 100
    e(myMs).to.be.above ms - 100


  it 'use year pattern', ()->
    test '[some YYMMddhhmmss]YY[some others]', 1, 'year'
  it 'use month pattern', ()->
    test '[some YYMMddhhmmss]MM[some others]', 2, 'month'
  it 'use day pattern', ()->
    test '[some YYMMddhhmmss]DD[some others]', 3, 'day'
  it 'use hour pattern', ()->
    test '[some YYMMddhhmmss]HH[some others]', 4, 'hour'
  it 'use minute pattern', ()->
    test '[some YYMMddhhmmss]mm[some others]', 5, 'minute'
  it 'use second pattern', ()->
    test '[some YYMMddhhmmss]ss[some others]', 6, 'second'
  it 'use mixed pattern', ()->
    test '[some YYMMddhhmmss]YYMMddhhmmss[some others]', 6, 'second'
  it 'use non-time pattern', ()->
    e(timeout '[some YYMMddhhmmss]b[some others]').to.eql [null, undefined]
