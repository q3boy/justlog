#mocha
e = require 'expect.js'
fs = require 'fs'
path = require 'path'
stream = require 'stream'

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

describe 'JustLog', ->
  jl = require '../lib/justlog'
  jl.config flushTime : 10
  {pre: predefined} = require '../lib/pattern'
  options = stdout = stderr = l = null
  dir = "#{__dirname}/log_file"

  beforeEach ->
    mock.clean()
    stdout = new mockStream
    stderr = new mockStream
    options =
      file:
        path : "[#{dir}/test.txt]"
      stdio :
        stdout : stdout
        stderr : stderr


  afterEach (done)->
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
    it 'check default options', (done)->
      l = new jl
      e(jl.INFO).to.be  l.INFO
      e(jl.DEBUG).to.be l.DEBUG
      e(jl.WARN).to.be  l.WARN
      e(jl.ERROR).to.be l.ERROR

      e(l.options.file.level).to.be           jl.EXCEPTION
      e(l.options.file.path).to.be            "[#{process.cwd()}/logs/_mocha-]YYYY-MM-DD[.log]"
      e(l.options.stdio.level).to.be          jl.ALL
      e(l.options.stdio.stdout).to.be         process.stdout
      e(l.options.stdio.stderr).to.be         process.stderr
      e(l.options.file.render.pattern).to.be  'file'
      e(l.options.stdio.render.pattern).to.be 'color'
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
        INFO\s+(out/test/)?tests/test-justlog\.(js|coffee):\d+\ssimple\sinfo\n
        \d{2}:\d{2}:\d{2}\s
        DEBUG\s+(out/test/)?tests/test-justlog\.(js|coffee):\d+\ssimple\sdebug\n
        $
      ///
      e(stderr.toStringNoColor()).to.match ///
        ^
        \d{2}:\d{2}:\d{2}\s
        WARN\s+(out/test/)?tests/test-justlog\.(js|coffee):\d+\ssimple\swarn\n
        \d{2}:\d{2}:\d{2}\s
        ERROR\s+(out/test/)?tests/test-justlog\.(js|coffee):\d+\ssimple\serror\n
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
        INFO\s+(out/test/)?tests/test-justlog\.(js|coffee):\d+\ssimple\sinfo\sdata2\s123\n
        \d{2}:\d{2}:\d{2}\s
        DEBUG\s+(out/test/)?tests/test-justlog\.(js|coffee):\d+\ssimple\sdebug\sdata3\s456\s1,2,3\s\{"a":1\}\n
        $
      ///
      e(stderr.toStringNoColor()).to.be ''
      done()
  describe 'file', ->
    it 'write warn & error log with default pattern', (done)->
      options.stdio = false
      l = new jl options
      l.info 'simple info'
      l.debug 'simple debug'
      l.warn 'simple warn'
      l.error 'simple error'
      l.close ->
        e(fs.readFileSync(l.file.path).toString()).to.match ///
          ^
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[WARN\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\swarn\n
          \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
          \[ERROR\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\serror\n
          $
        ///
        done()

    it 'rename file when current stream is not closed', (done)->
      options.stdio.level = 0
      options.file._watcher_timeout = 10

      l = new jl options
      flag = 0
      l.on 'rename', (file) ->
        flag++
        e(file).to.be l.file.path
      l.warn 'simple warn' # first log
      setTimeout -> # remove 30 ms later
        fs.renameSync l.file.path, l.file.path+'.move'
      , 300
      setTimeout -> # second log 60 ms later
        l.error 'simple error'
      , 600
      setTimeout -> # remove 30 ms later
        fs.renameSync l.file.path, l.file.path+'.move1'
      , 900
      setTimeout -> # second log 60 ms later
        l.error 'simple error2'
      , 1200
      setTimeout -> # check two logfile 90 ms later
        e(flag).to.be 2
        l.close ()->
          e(fs.readFileSync(l.file.path+'.move').toString()).to.match ///
            ^
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
            \[WARN\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\swarn\n
            $
          ///
          e(fs.readFileSync(l.file.path+'.move1').toString()).to.match ///
            ^
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
            \[ERROR\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\serror\n
            $
          ///
          e(fs.readFileSync(l.file.path).toString()).to.match ///
            ^
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
            \[ERROR\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\serror2\n
            $
          ///
          done()
      , 1500
    it 'file inode changed when current stream is not closed', (done)->
      # return done()
      options.stdio = false
      options.file._watcher_timeout = 10
      l = new jl options
      flag = 0
      l.on 'rename', (file) ->
        flag++
        e(file).to.be l.file.path
      l.warn 'simple warn' # first log
      setTimeout -> # remove 30 ms later
        fs.renameSync l.file.path, l.file.path+'.move'
        fs.writeFileSync l.file.path, 'somedata1\n'
      , 300
      setTimeout -> # second log 60 ms later
        l.error 'simple error'
      , 600
      setTimeout -> # remove 30 ms later
        fs.renameSync l.file.path, l.file.path+'.move1'
        fs.writeFileSync l.file.path, 'somedata2\n'
      , 900
      setTimeout -> # second log 60 ms later
        l.error 'simple error2'
      , 1200
      setTimeout -> # check two logfile 90 ms later
        e(flag).to.be 2
        l.close ()->
          e(fs.readFileSync(l.file.path+'.move').toString()).to.match ///
            ^
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
            \[WARN\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\swarn\n
            $
          ///
          e(fs.readFileSync(l.file.path+'.move1').toString()).to.match ///
            ^
            somedata1\n
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
            \[ERROR\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\serror\n
            $
          ///
          e(fs.readFileSync(l.file.path).toString()).to.match ///
            ^
            somedata2\n
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
            \[ERROR\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\serror2\n
            $
          ///
          done()
      , 1500

    it 'logfile rotate by time', (done)->
      nowMs = new Date().getMilliseconds()
      this.timeout 10000
      setTimeout ->
        options.stdio = false
        options.file.watcher_timeout = 10
        options.file.path = "[#{dir}]/ss.txt"
        l = new jl options
        files = [l.file.path]
        l.on 'rotate', (prev, curr) ->
          files.push curr
        tflag = 0
        l.on 'timer', (ms)->
          e(ms).to.below 1001
          e(ms).to.above 99
          tflag++
          # console.log prev, curr
        l.warn 'simple warn' # first log
        setTimeout ->
          l.error 'simple error1'
        , 1000
        setTimeout ->
          l.error 'simple error2'
        , 2000
        setTimeout ->
          l.error 'simple error3'
          l.close ->
            # console.log files
            e(tflag).to.above 3
            e(tflag).to.below 6
            flag = 0
            for k in files
              switch ++flag
                when 1
                  e(fs.readFileSync(k).toString()).to.match ///
                    ^
                    \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
                    \[WARN\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\swarn\n
                    $
                  ///
                when 2
                  e(fs.readFileSync(k).toString()).to.match ///
                    ^
                    \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
                    \[ERROR\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\serror1\n
                    $
                  ///
                when 3
                  e(fs.readFileSync(k).toString()).to.match ///
                    ^
                    \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
                    \[ERROR\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\serror2\n
                    $
                  ///
                when 4
                  e(fs.readFileSync(k).toString()).to.match ///
                    ^
                    \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
                    \[ERROR\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\serror3\n
                    $
                  ///
              fs.unlinkSync k
            e(flag).to.be 4
            done()
        , 3000
      , nowMs + 10
  describe 'middleware', ->
    it 'simple 200 response', (done)->
      m = jl.middleware options
      l = m.justlog
      mock.resp.statusCode = 200
      mock.req.url = '/simple_200'
      m mock.req, mock.resp, -> setTimeout (->mock.resp.end 'some data1'), 20
      setTimeout ->
        mock.resp.end 'some data'
        std = stdout.toString()
        e(stdout.toString()).to.match ///
          ^
          \x1b\[33m127\.0\.0\.1\x1b\[0m\s
          -\s
          -\s
          \[\d{1,2}/\w{3}/\d{4}:\d\d:\d\d:\d\d\s[\+\-]?\d{4}\]\s
          "\x1b\[32mGET\x1b\[0m\s\x1b\[4m\x1b\[1m\x1b\[34m/simple_200\x1b\[0m\sHTTP/1.1"\s
          \x1b\[32m200\x1b\[0m\s-\s
          "\x1b\[34mmock\srefer\x1b\[0m"\s
          "\x1b\[36mmock\sserver\x1b\[0m"\s
          [12]\d\n
        ///

        fbody = fs.readFileSync(l.file.path).toString()
        e(fbody).to.match
        ///
          ^
          127\.0\.0\.1\s
          -\s
          -\s
          \[\d{1,2}/\w{3}/\d{4}:\d\d:\d\d:\d\d\s[\+\-]?\d{4}\]\s
          "GET\s /simple_200\sHTTP/1.1"\s
          200\s-\s
          "mock\srefer"\s
          "mock\sserver"\s
          [12]\d\n
        ///
        done()
      , 100


      # m()
