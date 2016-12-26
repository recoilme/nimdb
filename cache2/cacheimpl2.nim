# {.compile: "cacheimpl2.c".}

const libname2* = "libs/linux/libcacheimpl2.so"

type Cache* = pointer
proc create_cache*(): Cache {.cdecl, importc: "create_cache", dynlib: libname2.}
proc set*(cache: Cache, key: cstring, value: ptr cstring, valueLen: cint): void {.cdecl, importc: "set", dynlib: libname2.}
proc get*(cache: Cache, key: cstring, value: ptr cstring): bool {.cdecl, importc: "get", dynlib: libname2.}
