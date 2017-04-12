## The first thing you will always need to do in order to start using pudge db,
## is to create a new instance of the ``Socket`` type using the ``newClient``
## procedure.
##
## Examples
## ========
##
## Connecting to a server
## ----------------------
##
## After you create a socket with the ``newClient`` procedure, you can easily
## connect it to a server running at a known hostname (or IP address) and port.
## To do so, use the example below.
##
## .. code-block:: Nim
##   var client = newClient("127.0.0.1",11213)
##
## Using a server
## ----------------------
##
## Base pudge commands is set and get. Where key is string, value is bytearray
## or string
##
## .. code-block:: Nim
##   var client = newClient("127.0.0.1",11213)
##   discard client.set("key", "val")
##   discard client.set("key", "new_val")
##   echo client.get("key")
##   client.quit()
##
## New command for reading cursor:
## .. code-block:: Nim
##   res = socket.getWithCursor(
##     "221:1701191301", 
##     100500, 
##     proc(key,value: string): bool = match(value, re".+true$") and match(value, re"^SCR")
##   )
## see test.nim

import net, random,  re, strutils, unittest

const NL = chr(13) & chr(10)

proc createSocket*():Socket =
  var socket = newSocket(domain = AF_INET, sockType = SOCK_STREAM,
    protocol = IPPROTO_TCP, buffered = false)
  return socket

proc newClient*(host: string = "127.0.0.1", port: int = 11213): Socket =
  result = createSocket()
  try:
    result.connect(host, Port(port))
    #setSockOpt(result, OptReuseAddr, true)
    #setSockOpt(result, OptReusePort, true)
  except:
    raise newException(IOError, "Couldn't connect to server")
  return result


proc set*(socket: Socket, key:string, val:string):bool =
  ##
  ## .. code-block:: Nim
  ##
  ##  let result = client.set("key", "val")
  ##  if result == true:
  ##    echo "STORED"
  ##  else:
  ##    echo "NOT STORED"
  socket.send("set " & key & " 0 0 " & $val.len & NL & val & NL)
  let res = socket.recvLine()
  return res == "STORED"

proc setNoreply*(socket: Socket, key:string, val:string):int =
  var message = "set " & key & " 0 0 " & $val.len & " noreply" & NL & val & NL
  return socket.send(message.cstring, message.len)

proc delete*(socket: Socket, key: string): bool =
  ##
  ## .. code-block:: Nim
  ##
  ##  let result = client.delete("key")
  ##  if result == true:
  ##    echo "DELETED"
  ##  else:
  ##    echo "NOT FOUND"
  socket.send("delete " & key & NL)
  return socket.recvLine() == "DELETED"

proc deleteNoreply*(socket: Socket, key: string, noreply: bool = false): int =
  var message = "delete " & key & " noreply" & NL
  return socket.send(message.cstring, message.len)

proc get*(socket: Socket, key:string):string  =
  ##
  ## .. code-block:: Nim
  ##
  ##  let result = client.get("key")
  ##  echo $result
  result = ""
  socket.send("get " & key & NL)
  let res = socket.recvLine()
  #echo res
  while true:
    if res == "END":
      break
    else:
      var size:int
      try:
        let params = splitWhitespace(res & "")
        size = parseInt(params[params.len-1])
      except:
        break
      
      var data:string =newStringOfCap(size)
      #low level reading from socket(memcopy to cstring)
      var readBytes = socket.recv( cstring(data), size)
      data.setLen(readBytes)
      while readBytes != size:
        var tmp = newStringOfCap(size - readBytes)
        var r = socket.recv(tmp, size - readBytes)
        tmp.setLen(r)
        data =  $data & $tmp
        readBytes = data.len
      discard socket.recv(7)#NL+END+NL
      result = $data
      break
  return result

proc getWithCursor*(
  socket: Socket,
  prefix: string,
  limit: int  = 1,
  processor: proc(key, value: string): bool = proc(x,y: string): bool = true
): seq[tuple[key: string, value: string]] =
  result = newSeq[tuple[key: string, value: string]]()
  let  request = "?type=cursor&prefix=" & prefix & "&limit=" & $limit
  var
    counter = 0
    tmp = newSeq[string]()
  socket.send("get " & request & NL)
  # we need to read a line first
  var line = socket.recvLine()
  # then if it contains something meaningful process it
  while line != "END" and line != "":    
    var 
      size:int
      key: string = ""
    try:
      let params = splitWhitespace(line & "")
      size = parseInt(params[params.len-1])
      assert(params[0] == "VALUE")
      key = params[1]
    except:
      break
    var data: string = newStringOfCap(size)
    #low level reading from socket(memcopy to cstring)
    var readBytes = socket.recv(cstring(data), size)
    data.setLen(readBytes)
    # addressing case when a packet ended mid-value (need to glue to pieces together)
    while readBytes != size:
      var tmp = newStringOfCap(size - readBytes)
      var r = socket.recv(tmp, size - readBytes)
      tmp.setLen(r)
      data =  $data & $tmp
      readBytes = data.len
      
    discard socket.recvLine() # this is actually reading the rest of line up to NL, i do not know how to make it more elegantly
    result.add((key,data))
    line = socket.recvLine()
  assert(socket.recvLine() == "END") # this is addressing a bug: cursor returns END twice

  return result
    
proc quit*(socket: Socket) =
  ## close current session
  socket.send("quit" & NL)
  socket.close()

when isMainModule:
  suite "Testing new cursor request":
    echo "Testing cursor"

    var client = newClient("tiger.surfy.ru", 11212)
    test "reading from a cursor that contains something and returns as many entries as asked for":
      let algs = @[2,4,7888]
      for i in countup(1,10):
        echo i, " iteration"
        for alg in algs:
          let 
            num = 10 * i
            prefix = "recs:" & $alg
            res = client.getWithCursor(prefix, num)
          echo "\t prefix '",prefix,  "' requested ", num, " entries, got ", res.len
          require(res.len == num)
    test "reading from a cursor that is empty":
      let 
        prefix = "upyachka"
        res = client.getWithCursor(prefix, 10)
      echo "used prefix ",prefix, " got ", res.len
      require(res == newSeq[tuple[key: string, value: string]]())
    test "reading from a cursor that requires fewer results than expected":
      let
        limit = 10 
        res = client.getWithCursor("recs:8013",limit)
      echo "requested: ",limit, " received: ",res.len
      check(res.len > 0)
      check(res.len < limit)
    test "checking data consistency":
      let res = client.getWithCursor("recs:2", 1000)
      var c = 0
      for answer in res:
        inc(c)
        let singleq = client.get(answer.key)
        require(answer.value == singleq)
      echo "compared ", c, " pairs from a cursor and individual requests"
    test "checking really long cursor":
      let 
        limit = 100000
        res = client.getWithCursor("recs:2", limit)
      var count = 0
      require(res.len == limit)
      randomize(limit)
      for i in countup(0,10):
        for j in countup(0,10):
          let
            indx = random(limit)
            rndItem = res[indx]
            resT = client.get(rndItem.key)
          require(resT == rndItem.value)
          inc(count)
      echo "checked ", count, " random elements in cursor of length ", limit
    client.quit