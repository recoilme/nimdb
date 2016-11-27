# PudgeDb - as simple as possible

## PudgeDb - it's simple async, multithreaded filesystem key/value storage with memcached protocol support
## Like memcached but stores data in files and memory
## It's writen in Nim and uses Sophia engine

Build
* build sophia shared library for your OS: https://github.com/pmwkaa/sophia
* build Nim for your OS: https://github.com/nim-lang/Nim
* add Nim/bin folder to your PATH
* add yaml: nimble install yaml
* compile: nim c --d:release --threads:on server.nim

Run
```
./server
#or with sophia library path
LD_LIBRARY_PATH=. ./server
```
Settings

Edit config.json, example:
```
{
  "address": "127.0.0.1",
  "port": 11213,
  "debug": false,
  "sophiaParams": [
    {
      "key": "sophia.path",
      "val": "./sophia"
    },
    {
      "key": "db",
      "val": "db"
    },
    {
      "key": "backup.path",
      "val": "backup"
    },
    {
      "key": "db.db.compaction.cache",
      "val": 8352
    },
    {
      "key": "db.db.compression",
      "val": "zstd"
    },
    {
      "key": "scheduler.threads",
      "val": 5
    },
    {
      "key": "db.db.mmap",
      "val": 1
    },
    {
      "key": "db.db.expire",
      "val": 0
    },
    {
      "key": "db.db.compaction.expire_period",
      "val": 36000
    }
  ]
}
```

Run
./pudgedb

Connect to socket via Telnet:
```
telnet localhost 11213
set key
value
#print:
STORED

get key

#print:
VALUE hello 0 5
world
END
#where 5 - size in bytes
#value on next line
#end
```

Or use any driver with memcached text protocol support: https://github.com/memcached/memcached/blob/master/doc/protocol.txt

From Nim:
```
import
  ../client,
  asyncdispatch

var pudge {.threadvar.}: PudgeAsyncClient

proc test():Future[void] {.async.} =
  echo "hi"
  echo $(await pudge.set("hello", "world"))# print true
  echo (await pudge.get("hello"))

proc getServer():Future[void] {.async.} =
  pudge = newPudge()
  await pudge.connect()
  echo "connected"

waitFor getServer()
echo repr(pudge)
waitFor test()
```

## Memcached commands

### set key 0 0 5\10\13value\10\13

where
* set - override or add key
* key - key string (max 1024 bytes)
* 0 - binary flag, ignored
* 0 - ttl, ignored
* 5 - size value in bytes
* \10\13 - new line
* value - value string (max 1000000 bytes)
* \10\13 - new line

Response: STORED or ERROR

### get key

response:
```
VALUE key 0 5
value
END

or
END
if key not found
```
where

0 - ignored bynary flag, 5 - size value in bytes
### quit
close current session

## Pudge commands (sophia storage)

### stat
sophia params

response:
```
Active clients:1 # not sophia param^ number pudge active clients, all other - sophia params
sophia.version:2.2
sophia.version_storage:2.2
sophia.build:1419633
sophia.status:online
sophia.errors:0
and so on
```
### env command param1 [param2]
get or set string or int sophia params

available commands:
* getint
* setint
* getstring
* setstring

example:

```
env getint db.db.index.count # get count of keys
100003
env getstring sophia.version # get sophia version
2.2
env getint backup.active # get is backup active
0
env getint backup.last # get last backup id
0
env setint backup.run 0 # run async backup
0 # 0 on success,  -1 on error
env getint backup.last # get last backup id
2
```

As all commands - you may run from command line, create backup example

```
echo env getint backup.last | nc 127.0.0.1 11213
2
# run backup
echo env setint backup.run 0| nc 127.0.0.1 11213
0
echo env getint backup.last | nc 127.0.0.1 11213
3
```
Now you may stop server and copy backup 3 folder

### die

command for debug purpose - close current session and gracefully stop server after next connect

command line example:

echo die| nc 127.0.0.1 11213 & echo die |nc 127.0.0.1 11213

socket will be available for next connect after 20-40 seconds

### sub

command for subscribe one server for succesful set command on another server
For example you have 2 servers

Master 127.0.0.1 11213

Reserv master on 127.0.0.1 11214

```
telnet 127.0.0.1 11213
sub 127.0.0.1 11214
0 - success subscription
```
now all changes on 11213 server will be sent to 11214 sever

You may subscribe pool of servers
```
telnet 127.0.0.1 11213
sub 127.0.0.1 11214
sub 127.0.0.1 11215
sub 127.0.0.1 11216
```
You may subscribe another server to subscribed server and so on

```
telnet 127.0.0.1 11216
sub 127.0.0.1 11213
```
Or create any topology what you want. For example ring of servers subscribed one on another like in cassandra topology

You may subscribe on the fly, but then you must delivery data from master server to subscribed via backup or programmaticaly

Right now monitoring not automated, but you may check server status via env command (sophia.status)

```
env getstring sophia.status
```

