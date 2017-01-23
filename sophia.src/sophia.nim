{.deadCodeElim: on.}
{.compile: "sophia.c".}

#
#  sophia database
#  sphia.org
# 
#  Copyright (c) Dmitry Simonenko
#  BSD License
#

proc env*(): pointer {.cdecl, importc: "sp_env", header: "sophia.h".}
proc document*(a2: pointer): pointer {.cdecl, importc: "sp_document", header: "sophia.h".}
proc setstring*(a2: pointer; a3: cstring; a4: pointer; a5: cint): cint {.cdecl,
    importc: "sp_setstring", header: "sophia.h".}
proc setint*(a2: pointer; a3: cstring; a4: int64): cint {.cdecl, importc: "sp_setint",
    header: "sophia.h".}
proc getobject*(a2: pointer; a3: cstring): pointer {.cdecl, importc: "sp_getobject",
    header: "sophia.h".}
proc getstring*(a2: pointer; a3: cstring; a4: ptr cint): pointer {.cdecl,
    importc: "sp_getstring", header: "sophia.h".}
proc getint*(a2: pointer; a3: cstring): int64 {.cdecl, importc: "sp_getint",
    header: "sophia.h".}
proc open*(a2: pointer): cint {.cdecl, importc: "sp_open", header: "sophia.h".}
proc destroy*(a2: pointer): cint {.cdecl, importc: "sp_destroy", header: "sophia.h".}
proc error*(a2: pointer): cint {.cdecl, importc: "sp_error", header: "sophia.h".}
proc service*(a2: pointer): cint {.cdecl, importc: "sp_service", header: "sophia.h".}
proc poll*(a2: pointer): pointer {.cdecl, importc: "sp_poll", header: "sophia.h".}
proc drop*(a2: pointer): cint {.cdecl, importc: "sp_drop", header: "sophia.h".}
proc set*(a2: pointer; a3: pointer): cint {.cdecl, importc: "sp_set", header: "sophia.h".}
proc upsert*(a2: pointer; a3: pointer): cint {.cdecl, importc: "sp_upsert",
    header: "sophia.h".}
proc delete*(a2: pointer; a3: pointer): cint {.cdecl, importc: "sp_delete",
    header: "sophia.h".}
proc get*(a2: pointer; a3: pointer): pointer {.cdecl, importc: "sp_get", header: "sophia.h".}
proc cursor*(a2: pointer): pointer {.cdecl, importc: "sp_cursor", header: "sophia.h".}
proc begin*(a2: pointer): pointer {.cdecl, importc: "sp_begin", header: "sophia.h".}
proc prepare*(a2: pointer): cint {.cdecl, importc: "sp_prepare", header: "sophia.h".}
proc commit*(a2: pointer): cint {.cdecl, importc: "sp_commit", header: "sophia.h".}