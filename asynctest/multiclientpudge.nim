import net, threadpool, times,
  ../pudgeclient,
  random,
  os

{.experimental.}

const NL = chr(13) & chr(10)

proc newTaskAsync(task:int) = 
  var socket = newClient("127.0.0.1",11213)
  let start = task * 100000 + 1
  let endd = start + 99999
  echo $start," :",$endd
  randomize()
  for i in start..endd:
    let rnd = random(100_000)+1
    let res = socket.get($rnd)
    #echo $i
  socket.quit()

proc newTaskSync(task:int) = 
  var socket = newClient("127.0.0.1",11213)
  randomize()
  
  for i in 0..1_000_000:
    let rnd = random(100_000)+1
    let res = socket.get($rnd)
    #echo $rnd
  socket.quit()

proc mainAsync()=
  echo "start"
  var t = toSeconds(getTime())
  for j in 1..5:
    t = toSeconds(getTime())
    parallel:
      for i in 0..9:
        spawn newTaskAsync(i)
  
    echo "Read time [s] ", $(toSeconds(getTime()) - t)  
    echo "sleep 10 sec"
    sleep(10000)
  echo "end"
    

proc mainSync()=
  echo "start"
  var t = toSeconds(getTime())
  for j in 1..1000:
    parallel:
      for i in 1..1:
        spawn newTaskSync(i)
    sleep(10000)
  echo "end"
  echo "Read time [s] ", $(toSeconds(getTime()) - t) 


mainAsync()