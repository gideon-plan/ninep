## passthrough.nim -- Passthrough filesystem proxying to host OS.

{.experimental: "strict_funcs".}

import std/[os, tables]
import wire, fs

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  PassthroughFs* = ref object of FileSystem
    root_path*: string
    paths*: Table[uint64, string]  ## qid.path -> real path
    next_path: uint64

# =====================================================================================================================
# Helpers
# =====================================================================================================================

proc alloc_path(pfs: PassthroughFs): uint64 =
  result = pfs.next_path
  inc pfs.next_path

proc register(pfs: PassthroughFs, real_path: string, is_dir: bool): Qid =
  let p = pfs.alloc_path()
  pfs.paths[p] = real_path
  let qtype = if is_dir: QtDir else: QtFile
  Qid(qtype: qtype, version: 0, path: p)

proc real_path(pfs: PassthroughFs, qid_path: uint64): string {.raises: [FsError].} =
  try:
    result = pfs.paths[qid_path]
  except KeyError:
    raise newException(FsError, "unknown fid")

# =====================================================================================================================
# Constructor
# =====================================================================================================================

proc new_passthrough*(root: string): PassthroughFs =
  result = PassthroughFs(root_path: root, paths: initTable[uint64, string](), next_path: 0)

# =====================================================================================================================
# FileSystem interface
# =====================================================================================================================

method attach*(pfs: PassthroughFs, uname, aname: string): (Qid, string) {.raises: [FsError].} =
  if not dirExists(pfs.root_path):
    raise newException(FsError, "root does not exist: " & pfs.root_path)
  let qid = pfs.register(pfs.root_path, true)
  (qid, pfs.root_path)

method walk*(pfs: PassthroughFs, path: seq[string]): seq[Qid] {.raises: [FsError].} =
  result = @[]
  var current = pfs.root_path
  for name in path:
    current = current / name
    if dirExists(current):
      result.add(pfs.register(current, true))
    elif fileExists(current):
      result.add(pfs.register(current, false))
    else:
      raise newException(FsError, "not found: " & current)

method open*(pfs: PassthroughFs, qid_path: uint64, mode: uint8): (Qid, uint32) {.raises: [FsError].} =
  discard pfs.real_path(qid_path)  # validate exists
  let qtype = if dirExists(pfs.real_path(qid_path)): QtDir else: QtFile
  (Qid(qtype: qtype, version: 0, path: qid_path), MaxMsgSize - 24)

method create*(pfs: PassthroughFs, dir_path: uint64, name: string, perm: uint32,
               mode: uint8): (Qid, uint32) {.raises: [FsError].} =
  let dir = pfs.real_path(dir_path)
  let full = dir / name
  if (perm and DmDir) != 0:
    try: createDir(full) except CatchableError as e: raise newException(FsError, e.msg)
    let qid = pfs.register(full, true)
    (qid, MaxMsgSize - 24)
  else:
    try: writeFile(full, "") except CatchableError as e: raise newException(FsError, e.msg)
    let qid = pfs.register(full, false)
    (qid, MaxMsgSize - 24)

method read*(pfs: PassthroughFs, qid_path: uint64, offset: uint64,
             count: uint32): string {.raises: [FsError].} =
  let rp = pfs.real_path(qid_path)
  if dirExists(rp):
    # Directory listing as stat entries
    var buf = ""
    try:
      for kind, path in walkDir(rp):
        let name = extractFilename(path)
        let is_dir = kind == pcDir
        let q = Qid(qtype: if is_dir: QtDir else: QtFile, version: 0, path: 0)
        let info = try: getFileInfo(path) except CatchableError: continue
        let s = Stat9(qid: q, mode: if is_dir: DmDir or 0o755 else: 0o644'u32,
                      name: name, length: uint64(info.size),
                      uid: "none", gid: "none", muid: "none")
        let sb = encode_stat(s)
        buf.add(encode_u16(uint16(sb.len)))
        buf.add(sb)
    except OSError as e:
      raise newException(FsError, "readdir: " & e.msg)
    let off = int(offset)
    if off >= buf.len: return ""
    return buf[off ..< min(off + int(count), buf.len)]
  else:
    let content = try: readFile(rp) except CatchableError as e: raise newException(FsError, e.msg)
    let off = int(offset)
    if off >= content.len: return ""
    return content[off ..< min(off + int(count), content.len)]

method write*(pfs: PassthroughFs, qid_path: uint64, offset: uint64,
              data: string): uint32 {.raises: [FsError].} =
  let rp = pfs.real_path(qid_path)
  if dirExists(rp):
    raise newException(FsError, "cannot write to directory")
  var content = try: readFile(rp) except CatchableError: ""
  let off = int(offset)
  if off + data.len > content.len:
    content.setLen(off + data.len)
  for i in 0 ..< data.len:
    content[off + i] = data[i]
  try: writeFile(rp, content) except CatchableError as e: raise newException(FsError, e.msg)
  uint32(data.len)

method stat*(pfs: PassthroughFs, qid_path: uint64): Stat9 {.raises: [FsError].} =
  let rp = pfs.real_path(qid_path)
  let info = try: getFileInfo(rp) except CatchableError as e: raise newException(FsError, e.msg)
  let is_dir = info.kind == pcDir
  Stat9(qid: Qid(qtype: if is_dir: QtDir else: QtFile, version: 0, path: qid_path),
        mode: if is_dir: DmDir or 0o755 else: 0o644'u32,
        name: extractFilename(rp), length: uint64(info.size),
        uid: "none", gid: "none", muid: "none")

method remove*(pfs: PassthroughFs, qid_path: uint64) {.raises: [FsError].} =
  let rp = pfs.real_path(qid_path)
  try:
    if dirExists(rp): removeDir(rp)
    else: removeFile(rp)
  except CatchableError as e:
    raise newException(FsError, e.msg)
  pfs.paths.del(qid_path)
