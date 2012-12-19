#mocha
e = require 'expect.js'
fs = require 'fs'
path = require 'path'
stream = require 'stream'

class mockStream
  constructor : () ->
    @chunks = []

  write : (chunk) ->
    @chunks.push chunk
  toString : (nocolor = true) ->
    data = ''
    for chunk in @chunks
      data += chunk.toString()
    data.replace /\x1b\[\d+m/g, ''
  clean : ->
    chunks = []

describe 'JustLog', ->
  jl = require '../lib/justlog'
  {pre: patterns} = require '../lib/pattern'
  options = stdout = stderr = l = null
  dir = "#{__dirname}/log_file"

  beforeEach ->
    stdout = new mockStream
    stderr = new mockStream
    options =
      file:
        path : "[#{dir}/test.txt]"
      stdio :
        stdout : stdout
        stderr : stderr


  afterEach (done)->
    l.close ()->
      setTimeout ->
        try fs.unlinkSync l.file.path if l.file and l.file.path
        try fs.unlinkSync l.file.path+'.move' if l.file and l.file.path
        try fs.rmdirSync dir
        done()
      , 100


  describe 'options init', ->
    it 'check default options', (done)->
      l = new jl
      e(l.options.file.level).to.be           jl.EXCEPTION
      e(l.options.file.path).to.be            "[#{process.cwd()}/logs/_mocha-]YYYY-MM-DD[.log]"
      e(l.options.stdio.level).to.be          jl.ALL
      e(l.options.stdio.stdout).to.be         process.stdout
      e(l.options.stdio.stderr).to.be         process.stderr
      e(l.options.file.render.pattern).to.be  patterns.FILE
      e(l.options.stdio.render.pattern).to.be patterns.COLOR
      setTimeout done, 100
  describe 'stdio', ->
    it 'stdout with default output pattern', (done)->
      options.file = false
      l = new jl options
      l.info 'simple info'
      l.debug 'simple debug'
      l.warn 'simple warn'
      l.error 'simple error'
      e(stdout.toString()).to.match ///
        ^
        \d{2}:\d{2}:\d{2}\s
        INFO\s+(out/test/)?tests/test-justlog\.(js|coffee):\d+\ssimple\sinfo\n
        \d{2}:\d{2}:\d{2}\s
        DEBUG\s+(out/test/)?tests/test-justlog\.(js|coffee):\d+\ssimple\sdebug\n
        $
      ///
      e(stderr.toString()).to.match ///
        ^
        \d{2}:\d{2}:\d{2}\s
        WARN\s+(out/test/)?tests/test-justlog\.(js|coffee):\d+\ssimple\swarn\n
        \d{2}:\d{2}:\d{2}\s
        ERROR\s+(out/test/)?tests/test-justlog\.(js|coffee):\d+\ssimple\serror\n
        $
      ///
      done()
  describe 'file', ->
    it 'write warn & warn log with default pattern', (done)->
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
      # return done()
      options.stdio = false
      options.file =
        watcher_timeout : 10
      l = new jl options
      l.warn 'simple warn' # first log
      setTimeout -> # remove 30 ms later
        fs.renameSync l.file.path, l.file.path+'.move'
      , 30
      setTimeout -> # second log 60 ms later
        l.error 'simple error'
      , 60
      setTimeout -> # check two logfile 90 ms later
        l.close ()->
          e(fs.readFileSync(l.file.path+'.move').toString()).to.match ///
            ^
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
            \[WARN\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\swarn\n
            $
          ///
          e(fs.readFileSync(l.file.path).toString()).to.match ///
            ^
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s
            \[ERROR\]\s+\((out/test/)?tests/test-justlog\.(js|coffee):\d+\)\ssimple\serror\n
            $
          ///
          done()
      , 90


