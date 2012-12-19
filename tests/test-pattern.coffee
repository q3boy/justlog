#mocha
e = require 'expect.js'
moment = require 'moment'
path = require 'path'

describe 'Pattern Tools', ->
  pat = require '../lib/pattern'
  describe 'compile', ->
    it 'simple string', ->
      render = pat.compile 'simple'
      e(render()).to.be 'simple'
    it 'with vars', ->
      render = pat.compile 'simple #{var1} simple'
      e(render({var1:'vars'})).to.be 'simple vars simple'
    it 'with time', ->
      for k in ['now', 'time', 'date', 'fulltime', 'numbertime', 'mstimestamp', 'timestamp', 'moment']
        render = pat.compile 'simple #{' + k + '} simple'
        e(render.time).to.be true
    it 'with trace stack', ->
      for k in ['file', 'lineno', 'stack', 'stackColored']
        render = pat.compile 'simple #{' + k + '} simple'
        e(render.stack).to.be true

  describe 'format', ->
    it 'no vars', ->
      render = pat.compile 'simple no color'
      e(pat.format render, null, 1).to.be 'simple no color\n'
    it 'level text colored and message', ->
      render = pat.compile 'simple colored #{levelColored} #{msg}'
      e(pat.format render, 'msg', 2).to.be 'simple colored \x1b[36mDEBUG\x1b[0m msg\n'
    it 'with predefined time', ->
      render = pat.compile 'simple colored #{time} #{msg}'
      el = new Date()
      el.setSeconds(el.getSeconds() - 1)
      lt = new Date()
      lt.setSeconds(lt.getSeconds() + 1)
      early = "simple colored #{moment(el).format 'HH:mm:ss'} msg\n"
      later = "simple colored #{moment(lt).format 'HH:mm:ss'} msg\n"
      e(pat.format render, 'msg', 3).to.above early
      e(pat.format render, 'msg', 3).to.below later
    it 'with custom time', ->
      render = pat.compile 'simple colored #{now "HH:mm:ss"} #{msg}'
      el = new Date()
      el.setSeconds(el.getSeconds() - 1)
      lt = new Date()
      lt.setSeconds(lt.getSeconds() + 1)
      early = "simple colored #{moment(el).format 'HH:mm:ss'} msg\n"
      later = "simple colored #{moment(lt).format 'HH:mm:ss'} msg\n"
      e(pat.format render, 'msg', 3).to.above early
      e(pat.format render, 'msg', 3).to.below later
    it 'tracestack', ->
      render = pat.compile 'simple colored #{stack} #{msg}'
      e(pat.format render, 'msg', 3).to.match /simple colored (out\/test\/)?tests\/test-pattern\.(js|coffee):\d+ msg\n/
    it 'trace stack with inline code', ->
      render = pat.compile 'simple colored #{stack} #{msg}'
      checkReg = /simple colored (out\/test\/)?tests\/test-pattern\.(js|coffee):\d+ msg\n/
      new Function('e', 'pat', 'render', 'checkReg', "e(pat.format(render, 'msg', 3)).to.match(checkReg);")(e, pat, render, checkReg);

