## Pudge db implements a high-level cross-platform tcp sockets interface to sophia db.
## 
##
## Building a server
## =================
##
## From source:
##
## .. code-block:: Nim
##  build sophia shared library for your OS: https://github.com/pmwkaa/sophia
##  build Nim lang for your OS: https://github.com/nim-lang/Nim
##  add Nim/bin folder to your PATH
##  add yaml pkg via nimble: nimble install yaml
##  compile: nim c pudge.nim
##  edit config.json and run server
##
## Connecting to a server via telnet
## ----------------------
##
## Pudge uses memcached protocol for base commands
##
## .. code-block:: Nim
##   telnet localhost 11213
##   set key 0 0 5
##   value
##   #print:
##   STORED
##   
##   get key
##   
##   #print:
##   VALUE hello 0 5
##   world
##   END
##   #where 5 - size in bytes
##   #value on next line
##   #end
##
## Or use any driver with memcached text protocol 
## support: https://github.com/memcached/memcached/blob/master/doc/protocol.txt

import
  asyncdispatch,
  net,
  strutils,
  tables,
  sophia,
  times,
  os,
  yaml,
  streams,
  macros,
  nativesockets,
  threadpool,
  locks,
  pudgeclient,
  parseopt

# types
type 
  Server = ref object
    socket  : Socket
    clients : seq[Socket]
    subscribers   : seq[Socket]

  SophiaParams = object
    key : string
    val : string

  Expectation = ref object
    keyMaxSize      : int32
    valueMaxSize    : int32
    cmdGetBatchSize : int32

  Config* = object
    address : string
    port    : int32
    debug*   : bool
    sophiaParams: seq[SophiaParams]
    expectation: Expectation
# enums
  Cmd = enum
    cmdSet = "set",
    cmdAdd = "add",
    cmdGet = "get",
    cmdDelete = "delete",
    cmdDie = "die",
    cmdStat = "stat",
    cmdEcho = "echo",
    cmdQuit = "quit",
    cmdUnknown = "unknown",
    cmdEnv = "env",
    cmdSub = "sub",
    cmdKeys = "keys"

  Status = enum
    stored = "STORED",
    notStored = "NOT_STORED",
    error = "ERROR",
    theEnd = "END",
    value = "VALUE"
    deleted = "DELETED"
    notFound = "NOT_FOUND"  
  
  Engine = enum
    engMemory = "MEMORY",
    engSophia = "SOPHIA"

# vars
var DEBUG : bool
var die : bool# global var?
var keyMaxSize: int = 30
var valueMaxSize: int = 800
var cmdGetBatchSize: int = 1000


#Global data
#var glock: Lock
#var gdata {.guard: glock.}: Table[string, string]

#contants
const NL = chr(13) & chr(10)
const CUR_ENGINE = Engine.engSophia
const GET_CMD_ENDING = $Status.theEnd & NL

#sophia vars
var env : pointer
var db : pointer
var L: Lock

proc newServer(): Server =
  ## Constructor for creating a new ``Server``.
  Server(socket: newSocket(), clients: @[], subscribers: @[])


proc debug(msg:string) =
  if DEBUG:
    acquire(L)
    echo $msg
    release(L)

proc closeClient(server: Server, client: Socket) =
  client.close()
  for i, c in server.clients:
    if c == client:
      server.clients.del(i)#is it GC safe? not sure..
      break

proc sendStatus(client: Socket,status: Status):void=
  client.send($status & NL)


proc processSet(server: Server, client: Socket, params: seq[string], asAdd: bool):void=
  ## set command example
  ## set key 0 0 5\10\13value\10\13
  ## Response: STORED or ERROR
  ## 
  ## In addition to standard memcached protocol, this command supports optional 
  ## "noreply" argument for replication purpose:
  ## set key 0 0 5 noreply\10\13value\10\13
  ## <nothing responds>
  if params.len<5:
    debug("wrong params for set command")
    sendStatus(client, Status.notStored)
    return
  var key:string = params[1]
  var size:int
  var noreply = false
  if params.len == 6:
    if params[5] == "noreply":
      noreply = true
    else:
      sendStatus(client, Status.error)
      return  

  try:
    size = parseInt(params[4])
  except:
    debug("error parse size")
    sendStatus(client, Status.notStored)
    return
  if size == 0:
    discard client.recvLine()
    sendStatus(client, Status.notStored)
    return
  #NL
  var val:string =(client.recv(size+2)).substr(0,size-1)
  case CUR_ENGINE:
    of Engine.engMemory:
      #{.locks: [glock].}:
        #echo repr(gdata)
        #if gdata.hasKey(key):
          #gdata.del(key)
        #gdata.add(key,val)
      if client != nil :
        sendStatus(client, Status.stored)
    of Engine.engSophia:
      var o = document(db)
      discard o.setstring("key".cstring, addr key[0], (key.len).cint)
      if asAdd:
        var res = db.get(o)
        if res != nil:
          sendStatus(client, Status.notStored)
          discard destroy(res)
          return
        else:
          o = document(db) # recreate document
          discard o.setstring("key".cstring, addr key[0], (key.len).cint)
      discard o.setstring("value".cstring, addr val[0], (val.len).cint)
      var rc = db.set(o);
      if (rc == -1):
        debug("Sophia write error for " & key)
        if not noreply:
          sendStatus(client, Status.notStored)
      else:
        if not noreply:
          sendStatus(client, Status.stored)
        #if server has subscribed servers - send set to it
        if server.subscribers.len > 0:
          for sub in server.subscribers:
            discard set(sub, key, val, true)
    else:
      if client != nil:
        sendStatus(client, Status.notStored)


proc processGet(client: Socket,params: seq[string]):void=
  ## get key [key2] [key3] .. [keyn]
  ## response example:
  ## VALUE key 0 5
  ## value
  ## END
  ## if key not found - value is empty
  if params.len<2:
    debug("wrong params for get command")
    sendStatus(client, Status.error)
    return
  var bufferLen = (20 + keyMaxSize + valueMaxSize) * min(cmdGetBatchSize, params.len - 1) 
  var bufferPos = 0 
  var buffer = cast[ptr array[0, char]](createU(char, bufferLen))
  for i in 1..(params.len - 1):
    if i mod cmdGetBatchSize == 0:
      discard client.send(buffer, bufferPos)
      bufferPos = 0
    var key = params[i]
    var val:string = nil
    case CUR_ENGINE:
      of Engine.engMemory:
        #{.locks: [glock].}:
          #if gdata.hasKey(key):
            #val = gdata[key]
        if val != nil:
          # TODO: rewrite using copyMem
          let s = $Status.value & " " & $key & " 0 " & $val.len & NL & $val & NL
          for c in s:
            buffer[bufferPos] = c
            inc(bufferPos)
            if (bufferPos >= bufferLen):
              bufferLen = bufferLen * 2
              buffer = resize(buffer, bufferLen)

      of Engine.engSophia:
        var o = document(db)
        discard o.setstring("key".cstring, addr key[0], (key.len).cint)
        o = db.get(o)
        if (o != nil):
          var size:cint = 0
          var valPointer = cast[ptr array[0,char]](o.getstring("value".cstring, addr size))

          if (bufferLen - bufferPos < (size + key.len + 20)):
            bufferLen = bufferLen * 2
            buffer = resize(buffer, bufferLen)

          var header = $Status.value & " " & $key & " 0 " & $size & NL
          copyMem(addr buffer[bufferPos], header.cstring, header.len)
          bufferPos += header.len

          copyMem(addr buffer[bufferPos], valPointer, size)
          bufferPos += size

          copyMem(addr buffer[bufferPos], NL.cstring, NL.len)
          bufferPos += NL.len

          discard destroy(o)

  if bufferLen - bufferPos < GET_CMD_ENDING.len:
      bufferLen = bufferLen * 2
      buffer = resize(buffer, bufferLen)

  copyMem(addr buffer[bufferPos], GET_CMD_ENDING.cstring, GET_CMD_ENDING.len)
  bufferPos += GET_CMD_ENDING.len

  discard client.send(buffer, bufferPos)
  dealloc(buffer)

proc processDelete(server: Server, client: Socket, params: seq[string]): void =
  ## delete key [noreply]
  ## response variants:
  ## DELETED
  ## NOT_FOUND
  if params.len < 2 or params.len > 3:
    debug("wrong params for delete command")
    sendStatus(client, Status.error)
    return

  var key = params[1]
  var noreply = false
  if params.len == 3:
    if params[2] == "noreply":
      noreply = true
    else:
      sendStatus(client, Status.error)
      return 

  case CUR_ENGINE:
    of Engine.engMemory:
      # TODO: remove from memory
      if not noreply:
        sendStatus(client, Status.notFound)

    of Engine.engSophia:
      if not noreply:
        var o = document(db)
        discard o.setstring("key".cstring, addr key[0], (key.len).cint)
        var res = db.get(o)
        if res == nil:
          sendStatus(client, Status.notFound)
          return
        else:
          discard destroy(res)

      var o = document(db)
      discard o.setstring("key".cstring, addr key[0], (key.len).cint)
      var res = db.delete(o)

      if server.subscribers.len > 0:
        for sub in server.subscribers:
          discard delete(sub, key, true)

      if not noreply:
        if res == 0:
          sendStatus(client, Status.deleted)
        else:
          sendStatus(client, Status.error)

proc processStat(server:Server, client: Socket):void =
  ## example stat
  var len:int
  len = server.clients.len
  client.send("server.clients:" & $len & NL)
  len = server.subscribers.len
  client.send("server.subscribers:" & $len & NL)
  case CUR_ENGINE:
    of Engine.engMemory:
      echo ""
    of Engine.engSophia:
      var cursor = env.getobject(nil)
      var o:pointer
      o = cursor.get(o)
      var msg = ""
      while o != nil:
        var size:cint = 0
        var keyPointer = o.getstring("key".cstring, addr size)
        var keyVal = ($(cast[ptr array[0,char]](keyPointer)[])).substr(0,size-1)

        var valPointer = o.getstring("value".cstring, addr size)
        var valVal = ""
        if size>0:
          valVal = ($(cast[ptr array[0,char]](valPointer)[])).substr(0,size-1)

        msg = msg & $keyVal & ":" & $valVal & NL

        o = cursor.get(o)
      discard destroy(cursor)
      client.send(msg)

    else:
      if client != nil:
        sendStatus(client, Status.error)


proc processEnv*(client: Socket,params: seq[string]):void =
  ## env command param1 [param2]
  ## 
  ## get or set sophia params
  ##
  ## .. code-block:: Nim
  ## 
  ##  available commands:
  ## 
  ##     getint
  ##     setint
  ##     getstring
  ##     setstring
  ## Example:
  ##
  ## .. code-block:: Nim
  ##
  ##  env getint db.db.index.count # get count of keys
  ##  As all commands - you may run from command line, create backup example
  ##  echo env getint backup.last | nc 127.0.0.1 11213
  ##  echo env setint backup.run 0| nc 127.0.0.1 11213
  ##  echo env getint backup.last | nc 127.0.0.1 11213
  var res = ""
  if params.len<3:
    res = $Status.error
  else:
    let cmd = params[1]
    case cmd:
      of "getint":
        res = $(env.getint(params[2]))
      of "getstring":
        var size:cint = 0
        var valPointer = env.getstring(params[2].cstring, addr size)
        if size>0:
          res = ($(cast[ptr array[0,char]](valPointer)[])).substr(0,size-1)
      of "setint":
        if params.len<4:
          res = $Status.error
        else:
          var intparam:clonglong
          try:
            intparam = parseBiggestInt(params[3]).clonglong
            res = $(env.setint(params[2],intparam))
          except:
            res = $Status.error
      of "setstring":
        if params.len<4:
          res = $Status.error
        else:
          res = $(env.setstring((params[2]).cstring, (params[3]).cstring, 0))
      else:
        res = $Status.error

  client.send($res & NL)

#sub 127.0.0.1 11214
proc processSub*(server: Server, client: Socket,params: seq[string]):void =
  ## command for subscribe one server for succesful set command on another server For example you have 2 servers
  ##
  ## .. code-block:: Nim
  ##
  ##  Master 127.0.0.1 11213
  ##  Reserved master on 127.0.0.1 11214
  ##  telnet 127.0.0.1 11213
  ##  sub 127.0.0.1 11214
  ##  0 - success subscription
  ##  now all changes on 11213 server will be sent to 11214 sever
  ##  You may subscribe pool of servers
  ##  You may subscribe another server to subscribed server and so on
  ##  You may subscribe on the fly, but then you must delivery data from master server to subscribed 
  ##  via backup or programmaticaly
  var res = ""
  if params.len<3:
    res = $Status.error
  else:
    let address = params[1]
    var intVal:int
    try:
      intVal = parseInt($params[2])
    except:
      intVal = -1
    if intVal >= 0:
      debug("trying add subscriber on address:" & address & " port:" & $intVal)
      try:
        var subscriber: Socket = newClient(address, intVal)
        server.subscribers.add(subscriber)
        res = "0"
      except:
        debug("error connect")
        res = $Status.error
    else:
      debug("error parsing port")
      res = $Status.error
  client.send($res & NL)

proc processKeys(client: Socket, params: seq[string]): void = 
  ## Simplified analogue of Redis KEYS command. Wildcard required.
  ## For example get all db keys:
  ## KEYS * 
  ## firstkey
  ## secondkey
  ## ...
  ## lastkey
  ## END
  ##
  ## Get all keys by prefix (only prefix supported unlike of Redis):
  ## KEYS foo*
  ## foo
  ## foobar
  ## foobaz
  ## END
  if params.len != 2:
    sendStatus(client, Status.error)
    return
  var pattern = params[1]
  if pattern.len == 0 or not(pattern[pattern.len - 1] == '*'):
    sendStatus(client, Status.error)
    return
  pattern = pattern.substr(0, pattern.len - 2)

  var cursor = cursor(env);
  var o = document(db)
  if pattern.len > 0:
    discard o.setstring("prefix".cstring, addr pattern[0], (pattern.len).cint)
  o = cursor.get(o)  
  while o != nil:
    var size: cint
    var keyPtr = o.getstring("key".cstring, addr size)
    var key = $(cast[ptr array[0,char]](keyPtr)[])
    key = key.substr(0, size - 1)
    client.send(key & NL)
    o = cursor.get(o)
  sendStatus(client, Status.theEnd)
  discard destroy(cursor)

proc parseLine(server: Server, client: Socket, line: string):bool =
  result = false
  let
    params = splitWhitespace(line & "")
    command = if params!=nil and params.len>0:toLowerAscii(params[0]) else: $Cmd.cmdUnknown
  # debug(line)
  case command:
    of $Cmd.cmdSet:
      processSet(server, client, params, false)
    of $Cmd.cmdAdd:
      processSet(server, client, params, true)
    of $Cmd.cmdGet:
      processGet(client,params)
    of $Cmd.cmdDelete:
      processDelete(server, client, params)  
    of $Cmd.cmdEcho:
      client.send(line & NL)
    of $Cmd.cmdStat:
      processStat(server, client)
    of $Cmd.cmdEnv:
      processEnv(client, params)
    of $Cmd.cmdDie:
      ## command for debug purpose - close current session and gracefully stop server after next connect
      die = true
      closeClient(server, client)
      result = true
    of $Cmd.cmdQuit:
      closeClient(server, client)
      result = true
    of $Cmd.cmdUnknown:
      debug("Wrong protocol, line: " & line)
      sendStatus(client,Status.error)
    of $Cmd.cmdsub:
      processSub(server, client, params)
    of $Cmd.cmdKeys:
      processKeys(client, params)
    else:
      debug("Unknown command: " & command)
      sendStatus(client,Status.error)
  return result

proc processClient(server: Server, client: Socket) =
  while true:
    var line {.inject.}: TaintedString = ""
    readLine(client, line)
    #var line = client.recvLine()
    if line != "":
      let stop = parseLine(server, client, line)
      if stop:
        break
    else:
      #It seems sock received "", this it means connection has been closed.
      closeClient(server, client)
      break

proc free(obj: pointer) {.importc: "free", header: "<stdio.h>"}

proc errorExit() =
  var size: cint
  var error = env.getstring("sophia.error", addr size);
  var msg = $(cast[ptr array[0,char]](error)[])
  debug("Error: " & msg)
  free(error)
  discard env.destroy()

proc initVars(conf:Config):void =
  ## Init all vars
  #{.locks: [glock].}:
    #gdata = initTable[string, string]()

  die = false
  echo "Engine:" & $CUR_ENGINE
  DEBUG = conf.debug
  keyMaxSize = conf.expectation.keyMaxSize
  valueMaxSize = conf.expectation.valueMaxSize
  cmdGetBatchSize = conf.expectation.cmdGetBatchSize
  case CUR_ENGINE:
    of Engine.engMemory:
      debug("MEMORY")
    of Engine.engSophia:
      # Create a Sophia environment
      env = env()

      # Set directory and add a db named test
      var sp = conf.sophiaParams

      for p in sp:
        echo "setup key:", p.key,"\tval:",p.val
        var intVal:int
        try:
          intVal = parseInt(p.val)
        except:
          intVal = -1
        if intVal >= 0:
          echo env.setint(($p.key).cstring, intVal.clonglong)
        else:
          echo env.setstring(($p.key).cstring, ($p.val).cstring, 0)

      # Get the db
      db = env.getobject("db.db")

      # Open the environment
      var rc = env.open()
      if (rc == -1):  errorExit()
    else:
      echo "Engine unknown"

proc readCfg*():Config  =
  ## read sophia and server params from config.json
  ## full list of commands see in sophia doc
  ##
  ## .. code-block:: Nim  
  ##    {
  ##    "address": "127.0.0.1",
  ##    "port": 11213,
  ##    "debug": false,
  ##    "sophiaParams": [
  ##      {
  ##        "key": "sophia.path",
  ##        "val": "./sophia"
  ##      },
  ##      {
  ##        "key": "db",
  ##        "val": "db"
  ##      },
  ##      {
  ##        "key": "backup.path",
  ##        "val": "backup"
  ##      },
  ##      {
  ##        "key": "db.db.compression",
  ##        "val": "zstd"
  ##      },
  ##      {
  ##        "key": "scheduler.threads",
  ##        "val": 5
  ##      },
  ##      {
  ##        "key": "db.db.mmap",
  ##        "val": 1
  ##      },
  ##      {
  ##        "key": "db.db.expire",
  ##        "val": 0
  ##      },
  ##      {
  ##        "key": "db.db.compaction.expire_period",
  ##        "val": 36000
  ##      }
  ##    ]
  ##    }
  var configFilepath = "config.json"
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      discard
    of cmdLongOption, cmdShortOption:
      case key
      of "config", "c":
        configFilepath = val
      else:
        discard
    else:
      discard

  echo "Read configuration from: " & configFilepath
  var s = newFileStream(configFilepath)
  var config:Config
  if not isNil(s):
    load(s, config)
    s.close()
    return config
  else:
    var sphList = newSeq[SophiaParams]()

    sphList.add(SophiaParams(key:"sophia.path",val:"./sophia"))
    sphList.add(SophiaParams(key:"db",val:"db"))
    return Config(address: "127.0.0.1", port: 11213, debug:false, sophiaParams : sphList)

proc serve*(conf:Config) =
  ## run server with Config
  initVars(conf)
  var server = newServer()# global var?
  server.socket = newSocket(domain = AF_INET, sockType = SOCK_STREAM,
    protocol = IPPROTO_TCP, buffered = true)
  setSockOpt(server.socket, OptReuseAddr, true)
  setSockOpt(server.socket, OptReusePort, true)
  server.socket.bindAddr(Port(conf.port),conf.address)
  server.socket.listen()
  echo("Server initialised!")

  while not die:
    var client: Socket = newSocket()
    debug("New client")
    server.socket.accept(client)
    server.clients.add client
    if DEBUG:
      processClient(server,client)
    else:
      spawn processClient(server, client)
  #die
  echo "die server"
  for i, c in server.clients:
    closeClient(server, c)
  server.socket.close()
  echo "exit"


when isMainModule:
    serve(readCfg())
    echo "Server died"