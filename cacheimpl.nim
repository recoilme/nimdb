import
  locks,
  hashes,
  math

## copied from sharedtables.nim
include "system/inclrtl"

type
  KeyValuePair[A, B] = tuple[hcode: Hash, key: A, val: B]
  KeyValuePairSeq[A, B] = ptr array[10_000_000, KeyValuePair[A, B]]
  SharedTable* [A, B] = object ## generic hash SharedTable
    data*: KeyValuePairSeq[A, B]
    counter, dataLen: int
    lock: Lock

template maxHash(t): expr = t.dataLen-1

include tableimpl

proc enlarge[A, B](t: var SharedTable[A, B]) =
  let oldSize = t.dataLen
  let size = oldSize * growthFactor
  var n = cast[KeyValuePairSeq[A, B]](allocShared0(
                                      sizeof(KeyValuePair[A, B]) * size))
  t.dataLen = size
  swap(t.data, n)
  for i in 0..<oldSize:
    let eh = n[i].hcode
    if isFilled(eh):
      var j: Hash = eh and maxHash(t)
      while isFilled(t.data[j].hcode):
        j = nextTry(j, maxHash(t))
      rawInsert(t, t.data, n[i].key, n[i].val, eh, j)
  deallocShared(n)



proc initSharedTable*[A, B](initialSize=64): SharedTable[A, B] =
  ## creates a new hash table that is empty.
  ##
  ## `initialSize` needs to be a power of two. If you need to accept runtime
  ## values for this you could use the ``nextPowerOfTwo`` proc from the
  ## `math <math.html>`_ module or the ``rightSize`` proc from this module.
  assert isPowerOfTwo(initialSize)
  result.counter = 0
  result.dataLen = initialSize
  result.data = cast[KeyValuePairSeq[A, B]](allocShared0(
                                      sizeof(KeyValuePair[A, B]) * initialSize))
  initLock result.lock

proc mget*[A, B](t: var SharedTable[A, B], key: A): var B =
  ## retrieves the value at ``t[key]``. The value can be modified.
  ## If `key` is not in `t`, the ``KeyError`` exception is raised.
  withLock t:
    var hc: Hash
    var index = rawGet(t, key, hc)
    let hasKey = index >= 0
    if hasKey: result = t.data[index].val
  if not hasKey:
    when compiles($key):
      raise newException(KeyError, "key not found: " & $key)
    else:
      raise newException(KeyError, "key not found")

template withValue*[A, B](t: var SharedTable[A, B], key: A,
                          value, body: untyped) =
  ## retrieves the value at ``t[key]``.
  ## `value` can be modified in the scope of the ``withValue`` call.
  ##
  ## .. code-block:: nim
  ##
  ##   sharedTable.withValue(key, value) do:
  ##     # block is executed only if ``key`` in ``t``
  ##     # value is threadsafe in block
  ##     value.name = "username"
  ##     value.uid = 1000
  ##
  acquire(t.lock)
  try:
    var hc: Hash
    var index = rawGet(t, key, hc)
    let hasKey = index >= 0
    if hasKey:
      var value {.inject.} = addr(t.data[index].val)
      body
  finally:
    release(t.lock)
## copy-paste ended

type 
    Cache* = ptr object
        lock: Lock
        data*: SharedTable[cstring, cstring]
        inited: bool

# override default hasing (mem address by default)
proc hash*(x0: cstring): Hash =
  var h: Hash = 0
  var x = $x0
  for i in 0..x.len-1:
    h = h !& ord(x[i])
  result = !$h

proc get*(cache: var Cache, key: cstring, value: var ptr cstring): bool =
  var t = cache.data
  var hc: Hash
  var index = rawGet(t, key, hc)
  if index >= 0:
    value = addr(t.data[index].val)
    return true
  else:
    return false

proc put*(cache: var Cache, key: cstring, val0: ptr cstring) =
  var val = val0[]
  var t = cache.data
  var hc: Hash
  var index = t.rawGet(key, hc)
  if index >= 0: t.data[index].val = val
  else: maybeRehashPutImpl(enlarge)

proc add*(cache: var Cache, key: cstring, val0: ptr cstring, valLen: cint) =
  var t = cache.data
  var valPtr = create(char, valLen + 1)
  copyMem(valPtr, val0, valLen)
  var val = $valPtr
  # var t = cache.data
  if mustRehash(t.dataLen, t.counter): enlarge(t)
  var hc: Hash
  var j = t.rawGetDeep(key, hc)
  rawInsert(t, t.data, key, val, hc, j)
  inc(t.counter) 

proc simpleGet*(t: var SharedTable[cstring, cstring], key: cstring): cstring =
  var hc: Hash
  var index = rawGet(t, key, hc)
  if index >= 0:
    return t.data[index].val
  else:
    return "".cstring
  

proc createCache*(): Cache =
  result = cast[Cache](allocShared0(sizeOf(Cache)))
  result.data = initSharedTable[cstring, cstring]()
  result.inited = false
  initLock(result.lock)
