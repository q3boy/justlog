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
      render = pat.compile 'simple {var1} simple'
      e(render({var1:'vars'})).to.be 'simple vars simple'
    it 'with empty vars', ->
      render = pat.compile 'simple {var1} simple'
      e(render({})).to.be 'simple - simple'
    it 'with empty vars without "-"', ->
      render = pat.compile 'simple {empty var1} simple', placeholder:''
      e(render({var1 : '', empty : (v) ->
        if v then v else ''
      })).to.be 'simple  simple'
    it 'with time', ->
      for k in ['now', 'time', 'date', 'fulltime', 'numbertime', 'mstimestamp', 'timestamp']
        render = pat.compile 'simple {' + k + '} simple'
        e(render.time).to.be true
    it 'with trace stack', ->
      for k in ['file', 'lineno', 'stack', 'stackColored']
        render = pat.compile 'simple {' + k + '} simple'
        e(render.stack).to.be true

  describe 'format', ->
    describe 'basic', ->
      it 'no vars', ->
        render = pat.compile 'no vars'
        e(pat.format render, null, 1).to.be 'no vars\n'
      it 'object vars', ->
        render = pat.compile 'object vars {foo}'
        e(pat.format render, {foo:'bar'}, 1).to.be 'object vars bar\n'
      it 'object vars and subvars', ->
        render = pat.compile 'object vars {foo} {foo1.bar1}'
        e(pat.format render, {foo:'bar', foo1:bar1:'bar1'}, 1).to.be 'object vars bar bar1\n'
      it 'call function with const', ->
        render = pat.compile 'object vars {foo "123"} {foo 456} {foo \'789\'} {foo true}'
        e(pat.format render, {foo:((v)->v), 'true' : 'true'}, 1).to.be 'object vars 123 456 789 true\n'
      it 'call function with vars', ->
        render = pat.compile 'object vars {foo bar}'
        e(pat.format render, {foo:((v)->v), bar:123}, 1).to.be 'object vars 123\n'
    describe 'predefines', ->
      it 'level text colored and message', ->
        render = pat.compile 'simple colored {color.level level} {msg}'
        e(pat.format render, 'msg', 2).to.be 'simple colored \x1b[36mDEBUG\x1b[0m msg\n'
      it 'with predefined time', ->
        render = pat.compile 'simple colored {time} {msg}'
        el = new Date()
        el.setSeconds(el.getSeconds() - 1)
        lt = new Date()
        lt.setSeconds(lt.getSeconds() + 1)
        early = "simple colored #{moment(el).format 'HH:mm:ss'} msg\n"
        later = "simple colored #{moment(lt).format 'HH:mm:ss'} msg\n"
        e(pat.format render, 'msg', 4).to.above early
        e(pat.format render, 'msg', 4).to.below later
      it 'with custom time', ->
        render = pat.compile 'simple colored {now \'HH:mm:ss\'} {msg}'
        el = new Date()
        el.setSeconds(el.getSeconds() - 1)
        lt = new Date()
        lt.setSeconds(lt.getSeconds() + 1)
        early = "simple colored #{moment(el).format 'HH:mm:ss'} msg\n"
        later = "simple colored #{moment(lt).format 'HH:mm:ss'} msg\n"
        e(pat.format render, 'msg', 4).to.above early
        e(pat.format render, 'msg', 4).to.below later
      it 'tracestack', ->
        render = pat.compile 'simple colored {stack} {msg}'
        e(pat.format render, 'msg', 4).to.match /simple colored (out\/test\/)?tests\/test-pattern\.(js|coffee):\d+ msg\n/
      it 'trace stack with inline code', ->
        render = pat.compile 'simple colored {stack} {msg}'
        checkReg = /simple colored (out\/test\/)?tests\/test-pattern\.(js|coffee):\d+ msg\n/
        new Function('e', 'pat', 'render', 'checkReg', "e(pat.format(render, 'msg', 8)).to.match(checkReg);")(e, pat, render, checkReg);
