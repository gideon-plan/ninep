## fs.nim -- FileSystem interface (method table).
##
## Abstract file tree that a 9P server exposes. Implementations: memfs, passthrough.

{.experimental: "strict_funcs".}

import wire

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  FsError* = object of NinepError

  FileSystem* = ref object of RootObj
    ## Abstract filesystem interface. Override methods to implement.

# =====================================================================================================================
# Interface methods (override in implementations)
# =====================================================================================================================

method attach*(fs: FileSystem, uname, aname: string): (Qid, string) {.base, raises: [FsError].} =
  raise newException(FsError, "not implemented")

method walk*(fs: FileSystem, path: seq[string]): seq[Qid] {.base, raises: [FsError].} =
  raise newException(FsError, "not implemented")

method open*(fs: FileSystem, qid_path: uint64, mode: uint8): (Qid, uint32) {.base, raises: [FsError].} =
  raise newException(FsError, "not implemented")

method create*(fs: FileSystem, dir_path: uint64, name: string, perm: uint32,
               mode: uint8): (Qid, uint32) {.base, raises: [FsError].} =
  raise newException(FsError, "not implemented")

method read*(fs: FileSystem, qid_path: uint64, offset: uint64,
             count: uint32): string {.base, raises: [FsError].} =
  raise newException(FsError, "not implemented")

method write*(fs: FileSystem, qid_path: uint64, offset: uint64,
              data: string): uint32 {.base, raises: [FsError].} =
  raise newException(FsError, "not implemented")

method stat*(fs: FileSystem, qid_path: uint64): Stat9 {.base, raises: [FsError].} =
  raise newException(FsError, "not implemented")

method wstat*(fs: FileSystem, qid_path: uint64, s: Stat9) {.base, raises: [FsError].} =
  raise newException(FsError, "not implemented")

method remove*(fs: FileSystem, qid_path: uint64) {.base, raises: [FsError].} =
  raise newException(FsError, "not implemented")

method clunk*(fs: FileSystem, qid_path: uint64) {.base, raises: [FsError].} =
  discard  # default: no-op
