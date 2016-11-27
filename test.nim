import
  pudge,
  pudgeclient,
  unittest,
  times,
  strutils,
  asyncdispatch,
  os

proc runServer(conf:Config):Future[void] {.async.} =
  serve(conf)
    
suite "test suite for pudge":
  setup:
    let result = 4
    let size = 100000
    const bytes = 512
    const content = repeatStr(bytes, "t")
    var conf:Config = readCfg()
    # run server in background thread
    #asyncCheck runServer(conf)# сучка консоль захватывает(

    sleep(1000)

  
  test "2 + 2 = 4":
    check(2+2 == result)
  
  test "insert:":
    var
      client = newClient("127.0.0.1",11213)
      key:string = nil
      val:string = nil
      res:bool
      t = toSeconds(getTime())

    echo "start: ",$(t)
    for i in 1..size:

      key = "key" & $i
      res = client.set(key, "val" & $i & content)
      if res == false:
        break
    check(res == true)
    echo "Insert time [s] ", $(toSeconds(getTime()) - t)
    client.quit()

  test "read":
    var
      client = newClient("127.0.0.1",11213)
      key:string = nil
      val:string = nil
      t = toSeconds(getTime())
    echo "size:",$size
    echo "start: ",$(t)
    for i in 1..size:

      key = "key" & $i
      val =  client.get(key)
      if (i == size):
        echo "val:", val
    check(val == "val" & $size & content)
    echo "Read time [s] ", $(toSeconds(getTime()) - t)
    client.quit()