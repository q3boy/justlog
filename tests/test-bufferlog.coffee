#mocha
e = require 'expect.js'
fs = require 'fs'
path = require 'path'
stream = require 'stream'
ep = require 'event-pipe'

class mockStream
  constructor : () -> @chunks = []
  write : (chunk) ->
    @chunks.push chunk
  clean : -> chunks = []
  toString : (nocolor = true) ->
    data = ''
    for chunk in @chunks
      data += chunk.toString()
    data
  toStringNoColor : (nocolor = true) ->
    data = ''
    for chunk in @chunks
      data += chunk.toString()
    data.replace /\x1b\[\d+m/g, '' # trim ansi color




mock =
  send : ''
  headers : {}
  req :
    url : '/'
    headers :
      'user-agent' : 'mock server'
      'referer'    : 'mock refer'
    socket :
      remoteAddress : '127.0.0.1'
    httpVersionMajor : 1
    httpVersionMinor : 1
    method : 'GET'
  resp :
    write : (data)-> mock.send += data.toString() if data?
    end : (data)-> mock.send += data.toString() if data?
    statusCode : 0
    setHeader : (name, value) -> mock.headers[name.toLowerCase()] = value
    getHeader : (name) -> mock.headers[name.toLowerCase()]
  clean : ->
    mock.send = ''
    mock.headers = {}
    mock.resp.statusCode = 0
    mock.url = '/'
mock.resp.headers = mock.headers

describe 'buffer JustLog', ->
  jl = require '../lib/justlog'
  {pre: predefined} = require '../lib/pattern'
  options = stdout = stderr = l = null
  dir = "#{__dirname}/log_file"

  beforeEach ->
    mock.clean()
    jl.config flushTime : 10
    stdout = new mockStream
    stderr = new mockStream
    options =
      file:
        path : "[#{dir}/test.txt]"
      stdio :
        stdout : stdout
        stderr : stderr
      bufferLength : 5


  afterEach (done)->
    jl.end()
    return done() if not l?
    l.close ()->
      setTimeout ->
        try
          for file in fs.readdirSync dir
            fs.unlinkSync "#{dir}/#{file}"
          fs.rmdirSync dir
        done()
      , 100
    l = null

  describe 'options init', ->
    it 'check options', (done)->
      l = new jl bufferLength : 5
      e(l.options.bufferLength).to.be 5
      setTimeout done, 100
  describe 'stdio', ->
    it 'stdout with default output pattern', (done)->
      options.file = false
      l = new jl options
      l.info 'simple info'
      l.debug 'simple debug'
      l.warn 'simple warn'
      l.error 'simple error'
      e(stdout.toStringNoColor()).to.match ///
        ^
        \d{2}:\d{2}:\d{2}\s
        INFO\s+(out/test/)?tests/test-bufferlog\.(js|coffee):\d+\ssimple\sinfo\n
        \d{2}:\d{2}:\d{2}\s
        DEBUG\s+(out/test/)?tests/test-bufferlog\.(js|coffee):\d+\ssimple\sdebug\n
        $
      ///
      e(stderr.toStringNoColor()).to.match ///
        ^
        \d{2}:\d{2}:\d{2}\s
        WARN\s+(out/test/)?tests/test-bufferlog\.(js|coffee):\d+\ssimple\swarn\n
        \d{2}:\d{2}:\d{2}\s
        ERROR\s+(out/test/)?tests/test-bufferlog\.(js|coffee):\d+\ssimple\serror\n
        $
      ///
      done()
    it 'stdout with default output pattern', (done)->
      options.file.level = 0
      options.stdio.level = jl.INFO | jl.DEBUG
      l = new jl options
      l.info 'simple info', 'data2', 123
      l.debug 'simple debug %s %d %s %j', 'data3', 456, [1, 2, 3], a:1
      l.warn 'simple warn %s'
      l.error 'simple error'
      e(stdout.toStringNoColor()).to.match ///
        ^
        \d{2}:\d{2}:\d{2}\s
        INFO\s+(out/test/)?tests/test-bufferlog\.(js|coffee):\d+\ssimple\sinfo\sdata2\s123\n
        \d{2}:\d{2}:\d{2}\s
        DEBUG\s+(out/test/)?tests/test-bufferlog\.(js|coffee):\d+\ssimple\sdebug\sdata3\s456\s1,2,3\s\{"a":1\}\n
        $
      ///
      e(stderr.toStringNoColor()).to.be ''
      done()
  describe 'file', ->
    it 'write log over buffer length', (done)->
      options.stdio = false
      l = new jl options
      l.warn 'simple warn'
      l.error 'simple error'
      l.error 'simple error'
      l.error 'simple error'
      l.error 'simple error'
      e(fs.readFileSync(l.file.path).toString()).to.eql ''
      e(l.file.stream._buffer.length).to.be 5
      l.error 'simple error'
      e(l.file.stream._buffer.length).to.be 0
      l.close ->
        e(fs.readFileSync(l.file.path).toString()).to.match ///
          ^
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[WARN\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\swarn\n
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[ERROR\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\serror\n
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[ERROR\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\serror\n
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[ERROR\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\serror\n
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[ERROR\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\serror\n
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[ERROR\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\serror\n
          $
        ///
        done()

    it 'write log when time out', (done)->
      options.stdio = false
      options.duration = 100
      l = new jl options
      l.warn 'simple warn'
      l.error 'simple error'
      e(fs.readFileSync(l.file.path).toString()).to.eql ''
      e(l.file.stream._buffer.length).to.be 2
      setTimeout ->
        e(fs.readFileSync(l.file.path).toString()).to.match ///
          ^
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[WARN\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\swarn\n
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[ERROR\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\serror\n
          $
        ///
        l.close done
      , 200

    it 'write multiple log when time out', (done)->
      options.stdio = false
      options.duration = 100
      l = jl.create options
      l.warn 'simple warn'
      l.error 'simple error'
      options2 =
        file:
          path : "[#{dir}/test1.txt]"
        stdio : false
        bufferLength : 5
        duration : 300
      l2 = jl.create options2
      l2.warn 'log warn'
      l2.error 'log error'
      setTimeout ->
        e(fs.readFileSync(l.file.path).toString()).to.eql ''
        e(l.file.stream._buffer.length).to.be 2
        e(fs.readFileSync(l2.file.path).toString()).to.eql ''
        e(l2.file.stream._buffer.length).to.be 2
      , 90
      setTimeout ->
        e(fs.readFileSync(l.file.path).toString()).to.match ///
          ^
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[WARN\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\swarn\n
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[ERROR\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\serror\n
          $
        ///
        e(fs.readFileSync(l2.file.path).toString()).to.eql ''
      , 200
      setTimeout ->
        e(fs.readFileSync(l2.file.path).toString()).to.match ///
          ^
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[WARN\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\slog\swarn\n
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[ERROR\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\slog\serror\n
          $
        ///
        ep([
          ->
            l.close @
          , ->
            l2.close @
        ], ->
          done()
        ).run()
      , 400

  describe 'end', ->
    it 'close all log inst', (done)->
      options.stdio = false
      options.duration = 100
      l = jl.create options
      l.warn 'simple warn'
      l.error 'simple error'
      options2 =
        file:
          path : "[#{dir}/test1.txt]"
        stdio : false
        bufferLength : 5
        duration : 300
      l2 = jl.create options2
      l2.warn 'log warn'
      l2.error 'log error'
      setTimeout ->
        e(fs.readFileSync(l.file.path).toString()).to.match ///
          ^
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[WARN\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\swarn\n
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[ERROR\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\ssimple\serror\n
          $
        ///
        e(fs.readFileSync(l2.file.path).toString()).to.eql ''
        jl.end ->
          e(fs.readFileSync(l2.file.path).toString()).to.match ///
            ^
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
            \[WARN\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\slog\swarn\n
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
            \[ERROR\]\s+\((out/test/)?tests/test-bufferlog\.(js|coffee):\d+\)\slog\serror\n
            $
          ///
          done()
      , 200

