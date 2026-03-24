## memfs.nim -- In-memory synthetic filesystem implementing FileSystem.

{.experimental: "strict_funcs".}

import std/[tables, times]
import wire, fs

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  MemNode* = ref object
    qid*: Qid
    name*: string
    mode*: uint32
    data*: string          ## file content (empty for dirs)
    children*: Table[string, MemNode]  ## dir entries
    parent*: MemNode
    mtime*: uint32
    atime*: uint32

  MemFs* = ref object of FileSystem
    root*: MemNode
    nodes*: Table[uint64, MemNode]  ## qid.path -> node
    next_path: uint64

# =====================================================================================================================
# Helpers
# =====================================================================================================================

proc now_epoch(): uint32 =
  uint32(epochTime().int)

proc alloc_path(mfs: MemFs): uint64 =
  result = mfs.next_path
  inc mfs.next_path

proc make_node(mfs: MemFs, name: string, mode: uint32, parent: MemNode): MemNode =
  let qtype = if (mode and DmDir) != 0: QtDir else: QtFile
  let path = mfs.alloc_path()
  result = MemNode(qid: Qid(qtype: qtype, version: 0, path: path),
                   name: name, mode: mode, data: "",
                   children: initTable[string, MemNode](),
                   parent: parent, mtime: now_epoch(), atime: now_epoch())
  mfs.nodes[path] = result

proc find_node(mfs: MemFs, path: uint64): MemNode {.raises: [FsError].} =
  try:
    result = mfs.nodes[path]
  except KeyError:
    raise newException(FsError, "no such file")

# =====================================================================================================================
# Constructor
# =====================================================================================================================

proc new_memfs*(): MemFs =
  result = MemFs(nodes: initTable[uint64, MemNode](), next_path: 0)
  result.root = result.make_node("/", DmDir or 0o755, nil)

# =====================================================================================================================
# FileSystem interface
# =====================================================================================================================

method attach*(mfs: MemFs, uname, aname: string): (Qid, string) {.raises: [FsError].} =
  (mfs.root.qid, "/")

method walk*(mfs: MemFs, path: seq[string]): seq[Qid] {.raises: [FsError].} =
  result = @[]
  var node = mfs.root
  for name in path:
    if node.qid.qtype != QtDir:
      raise newException(FsError, "not a directory: " & node.name)
    if name notin node.children:
      raise newException(FsError, "file not found: " & name)
    try:
      node = node.children[name]
    except KeyError:
      raise newException(FsError, "file not found: " & name)
    result.add(node.qid)

method open*(mfs: MemFs, qid_path: uint64, mode: uint8): (Qid, uint32) {.raises: [FsError].} =
  let node = mfs.find_node(qid_path)
  node.atime = now_epoch()
  (node.qid, MaxMsgSize - 24)

method create*(mfs: MemFs, dir_path: uint64, name: string, perm: uint32,
               mode: uint8): (Qid, uint32) {.raises: [FsError].} =
  let dir = mfs.find_node(dir_path)
  if dir.qid.qtype != QtDir:
    raise newException(FsError, "not a directory")
  if name in dir.children:
    raise newException(FsError, "file exists: " & name)
  let node = mfs.make_node(name, perm, dir)
  dir.children[name] = node
  dir.mtime = now_epoch()
  (node.qid, MaxMsgSize - 24)

method read*(mfs: MemFs, qid_path: uint64, offset: uint64,
             count: uint32): string {.raises: [FsError].} =
  let node = mfs.find_node(qid_path)
  if node.qid.qtype == QtDir:
    # Return stat entries for directory listing
    var buf = ""
    for name, child in node.children:
      let s = Stat9(qid: child.qid, mode: child.mode, name: child.name,
                    length: uint64(child.data.len), mtime: child.mtime,
                    atime: child.atime, uid: "none", gid: "none", muid: "none")
      let stat_bytes = encode_stat(s)
      buf.add(encode_u16(uint16(stat_bytes.len)))
      buf.add(stat_bytes)
    let off = int(offset)
    if off >= buf.len:
      return ""
    let end_pos = min(off + int(count), buf.len)
    return buf[off ..< end_pos]
  else:
    node.atime = now_epoch()
    let off = int(offset)
    if off >= node.data.len:
      return ""
    let end_pos = min(off + int(count), node.data.len)
    return node.data[off ..< end_pos]

method write*(mfs: MemFs, qid_path: uint64, offset: uint64,
              data: string): uint32 {.raises: [FsError].} =
  let node = mfs.find_node(qid_path)
  if node.qid.qtype == QtDir:
    raise newException(FsError, "cannot write to directory")
  let off = int(offset)
  # Extend if needed
  if off + data.len > node.data.len:
    node.data.setLen(off + data.len)
  for i in 0 ..< data.len:
    node.data[off + i] = data[i]
  node.mtime = now_epoch()
  inc node.qid.version
  result = uint32(data.len)

method stat*(mfs: MemFs, qid_path: uint64): Stat9 {.raises: [FsError].} =
  let node = mfs.find_node(qid_path)
  Stat9(qid: node.qid, mode: node.mode, name: node.name,
        length: uint64(node.data.len), mtime: node.mtime,
        atime: node.atime, uid: "none", gid: "none", muid: "none")

method remove*(mfs: MemFs, qid_path: uint64) {.raises: [FsError].} =
  let node = mfs.find_node(qid_path)
  if node.parent == nil:
    raise newException(FsError, "cannot remove root")
  if node.qid.qtype == QtDir and node.children.len > 0:
    raise newException(FsError, "directory not empty")
  if node.parent != nil:
    node.parent.children.del(node.name)
    node.parent.mtime = now_epoch()
  mfs.nodes.del(qid_path)
