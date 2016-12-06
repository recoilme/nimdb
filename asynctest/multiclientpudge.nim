import net, threadpool, times,
  ../pudgeclient,
  random
{.experimental.}

const NL = chr(13) & chr(10)

proc newTaskAsync(task:int) = 
  var socket = newClient("127.0.0.1",11213)
  let start = task * 100000 + 1
  let endd = start + 99999
  echo $start," :",$endd
  randomize()
  for i in start..endd:
    let rnd = random(1_000_000)+1
    let res = socket.get($rnd)
    #echo $i
  socket.quit()

proc newTaskSync(task:int) = 
  var socket = newClient("127.0.0.1",11213)
  randomize()
  
  for i in 0..1_000_000:
    let rnd = random(1_000_000)+1
    let res = socket.get($rnd)
    #echo $rnd
  socket.quit()

proc mainAsync()=
  echo "start"
  var t = toSeconds(getTime())
  parallel:
    for i in 0..9:
      spawn newTaskAsync(i)
  echo "end"
  echo "Read time [s] ", $(toSeconds(getTime()) - t)    

proc mainSync()=
  echo "start"
  var t = toSeconds(getTime())
  parallel:
    for i in 1..1:
      spawn newTaskSync(i)
  echo "end"
  echo "Read time [s] ", $(toSeconds(getTime()) - t) 

mainAsync()