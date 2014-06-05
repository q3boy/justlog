e      = require 'expect.js'
fs     = require 'fs'
Stream = require '../lib/stream'

mockPath = "#{__dirname}/mock"
filePath = "#{mockPath}/stream.log"

describe 'Stream', ->
  before (done)->
    fs.mkdirSync mockPath
    done()

  beforeEach (done)->
    fs.writeFileSync filePath, '', 'utf-8'
    done()

  afterEach (done)->
    fs.writeFileSync filePath, '', 'utf-8'
    done()

  after (done)->
    fs.unlinkSync filePath
    fs.rmdirSync mockPath
    done()

  it 'write', (done)->
    stream = Stream
      filePath : filePath
    stream.write 'msg\n'
    stream.write 'msg\n'
    setTimeout ->
      str = fs.readFileSync filePath, 'utf-8'
      e(str).to.be 'msg\nmsg\n'
      e(stream._buffer.length).to.be 0
      stream.end()
      done()
    , 300

  it 'write on buffer over', (done)->
    stream = Stream
      bufferLength : 100
      filePath : filePath
    result = []
    for i in [0...100]
      result.push 'msg\n'
      stream.write 'msg\n'
      str = fs.readFileSync filePath, 'utf-8'
      e(str).to.be ''
    result.push 'msg\n'
    stream.write 'msg\n'
    setTimeout ->
      str = fs.readFileSync filePath, 'utf-8'
      e(str).to.be result.join ''
      e(stream._buffer.length).to.be 0
      stream.end()
      done()
    , 300

  it 'end', (done)->
    stream = Stream
      filePath : filePath
    stream.write 'msg\n'
    stream.end()
    setTimeout ->
      str = fs.readFileSync filePath, 'utf-8'
      e(str).to.be 'msg\n'
      e(stream._buffer.length).to.be 0
      done()
    , 200
