## client.nim -- 9P client: version, attach, walk, open, read, write, stat, clunk.

{.experimental: "strict_funcs".}

import std/tables
import wire, msg, transport, lattice

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  NinepClient* = ref object
    conn*: NinepConn
    msize*: uint32
    version*: string
    root_qid*: Qid
    root_fid*: uint32
    next_tag: uint16
    next_fid: uint32
    fid_qids: Table[uint32, Qid]  ## fid -> qid mapping

# =====================================================================================================================
# Helpers
# =====================================================================================================================

proc alloc_tag(c: NinepClient): uint16 =
  result = c.next_tag
  if c.next_tag == 0xFFFE: c.next_tag = 1
  else: inc c.next_tag

proc alloc_fid(c: NinepClient): uint32 =
  result = c.next_fid
  inc c.next_fid

proc check_error(r: Msg9) {.raises: [NinepError].} =
  if r.mtype == Rerror:
    raise newException(NinepError, r.ename)
  if r.mtype == Rlerror:
    raise newException(NinepError, "errno " & $r.lerror_ecode)

# =====================================================================================================================
# Connect
# =====================================================================================================================

proc connect*(host: string, port: int, aname: string = "",
              uname: string = "none",
              msize: uint32 = MaxMsgSize): NinepClient {.raises: [NinepError].} =
  result = NinepClient(next_tag: 1, next_fid: 1, fid_qids: initTable[uint32, Qid]())
  result.conn = tcp_dial(host, port)
  # Version
  let ver_msg = Msg9(mtype: Tversion, tag: NoTag, msize: msize, version: "9P2000")
  send_msg(result.conn, ver_msg)
  let rver = recv_msg(result.conn)
  if rver.mtype != Rversion:
    raise newException(NinepError, "expected Rversion, got " & $rver.mtype)
  result.msize = rver.msize
  result.version = rver.version
  # Attach
  result.root_fid = result.alloc_fid()
  let att = Msg9(mtype: Tattach, tag: result.alloc_tag(), attach_fid: result.root_fid,
                 attach_afid: NoFid, attach_uname: uname, attach_aname: aname)
  send_msg(result.conn, att)
  let ratt = recv_msg(result.conn)
  check_error(ratt)
  if ratt.mtype != Rattach:
    raise newException(NinepError, "expected Rattach")
  result.root_qid = ratt.attach_qid
  result.fid_qids[result.root_fid] = result.root_qid

# =====================================================================================================================
# Operations
# =====================================================================================================================

proc walk*(c: NinepClient, names: seq[string]): Result[(uint32, seq[Qid]), NinepError] =
  ## Walk from root. Returns (new_fid, qids).
  let newfid = c.alloc_fid()
  let m = Msg9(mtype: Twalk, tag: c.alloc_tag(), walk_fid: c.root_fid,
               walk_newfid: newfid, walk_names: names)
  try:
    send_msg(c.conn, m)
    let r = recv_msg(c.conn)
    check_error(r)
    if r.walk_qids.len > 0:
      c.fid_qids[newfid] = r.walk_qids[^1]
    Result[(uint32, seq[Qid]), NinepError].good((newfid, r.walk_qids))
  except NinepError as e:
    Result[(uint32, seq[Qid]), NinepError].bad(e[])

proc open*(c: NinepClient, fid: uint32, mode: uint8 = Oread): Result[(Qid, uint32), NinepError] =
  let m = Msg9(mtype: Topen, tag: c.alloc_tag(), open_fid: fid, open_mode: mode)
  try:
    send_msg(c.conn, m)
    let r = recv_msg(c.conn)
    check_error(r)
    Result[(Qid, uint32), NinepError].good((r.open_qid, r.open_iounit))
  except NinepError as e:
    Result[(Qid, uint32), NinepError].bad(e[])

proc read*(c: NinepClient, fid: uint32, offset: uint64 = 0,
           count: uint32 = 8192): Result[string, NinepError] =
  let m = Msg9(mtype: Tread, tag: c.alloc_tag(), read_fid: fid,
               read_offset: offset, read_count: count)
  try:
    send_msg(c.conn, m)
    let r = recv_msg(c.conn)
    check_error(r)
    Result[string, NinepError].good(r.read_data)
  except NinepError as e:
    Result[string, NinepError].bad(e[])

proc write*(c: NinepClient, fid: uint32, data: string,
            offset: uint64 = 0): Result[uint32, NinepError] =
  let m = Msg9(mtype: Twrite, tag: c.alloc_tag(), write_fid: fid,
               write_offset: offset, write_data: data)
  try:
    send_msg(c.conn, m)
    let r = recv_msg(c.conn)
    check_error(r)
    Result[uint32, NinepError].good(r.write_count)
  except NinepError as e:
    Result[uint32, NinepError].bad(e[])

proc create*(c: NinepClient, fid: uint32, name: string, perm: uint32,
             mode: uint8 = Ordwr): Result[(Qid, uint32), NinepError] =
  let m = Msg9(mtype: Tcreate, tag: c.alloc_tag(), create_fid: fid,
               create_name: name, create_perm: perm, create_mode: mode)
  try:
    send_msg(c.conn, m)
    let r = recv_msg(c.conn)
    check_error(r)
    Result[(Qid, uint32), NinepError].good((r.created_qid, r.created_iounit))
  except NinepError as e:
    Result[(Qid, uint32), NinepError].bad(e[])

proc stat*(c: NinepClient, fid: uint32): Result[Stat9, NinepError] =
  let m = Msg9(mtype: Tstat, tag: c.alloc_tag(), stat_fid: fid)
  try:
    send_msg(c.conn, m)
    let r = recv_msg(c.conn)
    check_error(r)
    Result[Stat9, NinepError].good(r.stat_data)
  except NinepError as e:
    Result[Stat9, NinepError].bad(e[])

proc clunk*(c: NinepClient, fid: uint32): Result[void, NinepError] =
  let m = Msg9(mtype: Tclunk, tag: c.alloc_tag(), clunk_fid: fid)
  try:
    send_msg(c.conn, m)
    let r = recv_msg(c.conn)
    check_error(r)
    c.fid_qids.del(fid)
    Result[void, NinepError](ok: true)
  except NinepError as e:
    Result[void, NinepError].bad(e[])

proc remove*(c: NinepClient, fid: uint32): Result[void, NinepError] =
  let m = Msg9(mtype: Tremove, tag: c.alloc_tag(), remove_fid: fid)
  try:
    send_msg(c.conn, m)
    let r = recv_msg(c.conn)
    check_error(r)
    c.fid_qids.del(fid)
    Result[void, NinepError](ok: true)
  except NinepError as e:
    Result[void, NinepError].bad(e[])

proc close*(c: NinepClient) {.raises: [].} =
  if c != nil and c.conn != nil:
    transport.close(c.conn)
