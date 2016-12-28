# {.compile: "cacheimpl2.c".}

const libname2* = "libs/linux/memcachelib.so"

type Cache* = pointer
proc create_cache*(c: cint): Cache {.cdecl, importc: "create_cache", dynlib: libname2.}
proc set*(cache: Cache, key: cstring, value: ptr cstring, valueLen: cint): cint {.cdecl, importc: "set", dynlib: libname2.}
proc get*(cache: Cache, key: cstring, value: ptr cstring): cint {.cdecl, importc: "get", dynlib: libname2.}
