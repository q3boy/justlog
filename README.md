# justlog 
[![Build Status](https://api.travis-ci.org/q3boy/justlog.png?branch=master)](http://travis-ci.org/q3boy/justlog)

justlog , focus on logging

## Features:

* coloured console logging
* file appender, with log rotate based on time
* configurable log message/patterns
* different log levels for different log categories (info debug warn error )
* can use as a connect middleware for access-log
 
## Installation

`npm install justlog`


## Usage

### Getting start
```javascript
// simple.js
var justlog = require('justlog');

var log = justlog(); 
l.info('simple', 'info');
l.debug({a:1, b:2});
l.warn([1,2,3,4]);
l.error('name:%s, number:%d', 'somename', 123);
```

```shell
$ node simple.js
```

the stdout/stderr is as below
```javascript
19:01:41 INFO  a.js:4 simple info
19:01:41 DEBUG a.js:5 {"a":1,"b":2}
19:01:41 WARN  a.js:6 1,2,3,4
19:01:41 ERROR a.js:7 name:somename, number:123
```
and also, you can got a log file on `logs/simple-%Y-%M-%D.log`

```javascript
2013-01-06 19:01:41 [WARN] (a.js:6) 1,2,3,4
2013-01-06 19:01:41 [ERROR] (a.js:7) name:somename, number:123
```


### Change log levels

```javascript
var log = justlog({
  file : {level: justlog.INFO | justlog.WARN} // file log levels
  stdio : {level: justlog.DEBUG | justlog.ERROR} // stdio log levels
});
```
available levels

* justlog.INFO
* justlog.DEBUG
* justlog.WARN
* justlog.ERROR
* justlog.ALL include all 4 level above
* justlog.EXCEPTION include WARN and ERROR

### Log only one way
```javascript
var stdLog = justlog({file : false}); // not write log file, only use stdio
var fileLog = justlog({stdio : false}); // not use stdio, only write a log file
});
```

### log error & warn messages into stdout

```javascript
var log = justlog({
  stdio: {
    stderr: process.stdout
  }
});
```

### custom log file path & log file rotate
```javascript
// write logs into filename.log and never rotate
var log1 = justlog({
  file: {
    path : '[filename.log]'
  }
});

// write logs into filename-%Y-%M-%D.log, and rotate every days
var log2 = justlog({
  file: {
    path : '[filename]-YYYY-MM-DD[.log]'
  }
}); 
```
time format use [moment string-format](http://momentjs.com/docs/#/parsing/string-format/)

rotate will be trigger when log filename changed.

### custom log line format
```javascript
var log = justlog({
  file : {
    pattern : '{fulltime} [{level}] {msg}' // use custom pattern
  }
  stdio : {
    pattern : 'simple-color' // use predefined pattern
  }
});
log.warn('log msg');
```
## All options
```javascript
{
  file : {
    level           : error | warn, // levels for filelog
    pattern         : 'file', // filelog pattern
    path            : '[logs/%main_script_name]YYYY-MM-DD[.log]', // log file path
    mode            : '0664', // log file mode
    dir_mode        : '2775', // if log dir is not exists, log dir mode when create
    _watcher_timeout : 5007,  // log file renamed watch timeout, DO NOT CHANGE THIS IF YOU REALLY KNOWN WHAT YOU DO.
  },
  stdio : {
    level   : error | warn | debug | info, // levels for stdio
    pattern : 'color', // stdio pattern
    stdout  : process.stdout, // stdout stream (for info & debug log)
    stderr  : process.stderr, // stderr stream (for warn & error log)
  }
}
```

## Middleware 
a connect middleware for apache-like accesslog.

middleware's has same options as normally justlog object, but has different default value

```javascript
var app = connect();
app.use(justlog.middleware({}));
```
### Middleware default options
```javascript
{
  file: {
    path    : '[logs/%main_script_name-access-]YYYY-MM-DD[.log]',
    pattern : 'accesslog-rt'
  }
  stdio :
    pattern : 'accesslog-color'
}
```

## Buffer Log
you can buffer your log if you have big visits.

```javascript
var log = justlog({
  duration : 1000, // flush buffer time, default is 1000
  bufferLength : 1000 // max buffer length, default is 0
  //... other options
});
```

or

```javascript
var log = justlog.create({
  duration : 1000, // flush buffer time, default is 1000
  bufferLength : 1000 // max buffer length, default is 0
});
```

### default options
```javascript
{
  duration : 1000,
  bufferLength : 0,
  // file: ...
  // stdio : ...
}
```

### close buffer log

```javascript
justlog.end(cb);
```



### About log pattern

Justlog has a powerful log line pattern support.
You can use variables, objects and functions in you patterns.
And you can define ansi color output patterns easily.


#### Syntax
`{var[ args...][@colors...]}`

* "{variable_name}": show varaible's value.
eg. `{remote-address}`
* "{object_name.prop_name}": show property value.
eg. `{headers.accepted-encoding}` 
* "{function_name "const1", "const2"}": show function's return value with const arguments.
eg. `{now "YYYY-MM-DD"}`
* "{function_name variable_name, object_name.prop_name}": show function's return value with variable arguments.
eg. `{color.status status-code}`
* "{something@color1,color2}": set output ansi color.
eg. `{url@blue,underline}`

#### Predefine variables

* msg          : (all log arguments).toString()
* level        : log level text align ("INFO ", "DEBUG", "WARN ", "ERROR")
* levelTrim    : log level text without align ("INFO", "DEBUG", "WARN", "ERROR")
* file         : log triggered file path
* lineno       : log triggered code line number
* stack        : alias for "file:lineno"
* stackColored : alias for colored stack
* time         : time format as "HH:mm:ss"
* date         : time format as "YYYY-MM-DD"
* fulltime     : time format as "YYYY-MM-DD HH:mm:ss"
* numbertime   : time format as "YYYYMMDDHHmmss"
* mstimestamp  : unix timestamp (with milliseconds)
* timestamp    : unix timestamp (with seconds)

#### Predefined functions

* now          : now formater function. eg. `{now "YYYY-MM-DD"}`
* color.status : add color for http status code. eg. `{color.status status}`
* color.method : add color for http request method. eg. `{color.method method}`
* color.event  : add color for event type. eg. `{color.event event}`
* color.level  : add color for log level. eg. `{color.level level}`

#### Predefined patterns

* simple-color: log message and colored level text
* simple-nocolor:  like simple without color
* color: tracestack, time, log message and colored level text
* nocolor: like color without color
* event-color: time, log message and colored event
* event-nocolor: like event-color without color
* file : fulltime, tracestack, log message and level text
* accesslog: apache access-log
* accesslog-rt: like access-log with response-time on the end (with microsecond)
* accesslog-color: like accesslog-rt with ansi colored

## License

`justlog` is published under BSD license.
