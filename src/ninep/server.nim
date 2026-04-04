{.experimental: "strictFuncs".}
## server.nim -- 9P server: accept loop, dispatch T-messages to FileSystem.

import std/[tables, atomics]
import wire, msg, transport, fs

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  FidEntry = object
    qid: Qid
    opened: bool

  NinepServer* = ref object
    listener: NinepListener
    filesystem*: FileSystem
    msize*: uint32
    running*: Atomic[bool]

# =====================================================================================================================
# Session handler
# =====================================================================================================================

proc handle_session(server: NinepServer, conn: NinepConn) =
  ## Handle one client session. Runs on the caller's thread.
  var fids = initTable[uint32, FidEntry]()

  while server.running.load():
    let req = try: recv_msg(conn) except NinepError: break

    proc send_error(tag: uint16, msg_text: string) =
      let r = Msg9(mtype: Rerror, tag: tag, ename: msg_text)
      try: send_msg(conn, r) except NinepError: discard

    case req.mtype
    of Tversion:
      let reply_msize = min(req.msize, server.msize)
      let ver = if req.version == "9P2000" or req.version == "9P2000.L": req.version
                else: "unknown"
      let r = Msg9(mtype: Rversion, tag: req.tag, msize: reply_msize, version: ver)
      try: send_msg(conn, r) except NinepError: break

    of Tattach:
      try:
        let (qid, _) = server.filesystem.attach(req.attach_uname, req.attach_aname)
        fids[req.attach_fid] = FidEntry(qid: qid, opened: false)
        let r = Msg9(mtype: Rattach, tag: req.tag, attach_qid: qid)
        send_msg(conn, r)
      except FsError as e: send_error(req.tag, e.msg)
      except NinepError: break

    of Twalk:
      try:
        let qids = server.filesystem.walk(req.walk_names)
        if qids.len > 0:
          fids[req.walk_newfid] = FidEntry(qid: qids[^1], opened: false)
        else:
          # Walk with 0 names clones the fid
          if req.walk_fid in fids:
            fids[req.walk_newfid] = fids[req.walk_fid]
        let r = Msg9(mtype: Rwalk, tag: req.tag, walk_qids: qids)
        send_msg(conn, r)
      except FsError as e: send_error(req.tag, e.msg)
      except KeyError as e: send_error(req.tag, e.msg)
      except NinepError: break

    of Topen:
      try:
        if req.open_fid notin fids:
          send_error(req.tag, "unknown fid")
          continue
        let entry = fids[req.open_fid]
        let (qid, iounit) = server.filesystem.open(entry.qid.path, req.open_mode)
        fids[req.open_fid] = FidEntry(qid: qid, opened: true)
        let r = Msg9(mtype: Ropen, tag: req.tag, open_qid: qid, open_iounit: iounit)
        send_msg(conn, r)
      except FsError as e: send_error(req.tag, e.msg)
      except KeyError as e: send_error(req.tag, e.msg)
      except NinepError: break

    of Tcreate:
      try:
        if req.create_fid notin fids:
          send_error(req.tag, "unknown fid")
          continue
        let entry = fids[req.create_fid]
        let (qid, iounit) = server.filesystem.create(entry.qid.path, req.create_name,
                                                      req.create_perm, req.create_mode)
        fids[req.create_fid] = FidEntry(qid: qid, opened: true)
        let r = Msg9(mtype: Rcreate, tag: req.tag, created_qid: qid, created_iounit: iounit)
        send_msg(conn, r)
      except FsError as e: send_error(req.tag, e.msg)
      except KeyError as e: send_error(req.tag, e.msg)
      except NinepError: break

    of Tread:
      try:
        if req.read_fid notin fids:
          send_error(req.tag, "unknown fid")
          continue
        let entry = fids[req.read_fid]
        let data = server.filesystem.read(entry.qid.path, req.read_offset, req.read_count)
        let r = Msg9(mtype: Rread, tag: req.tag, read_data: data)
        send_msg(conn, r)
      except FsError as e: send_error(req.tag, e.msg)
      except KeyError as e: send_error(req.tag, e.msg)
      except NinepError: break

    of Twrite:
      try:
        if req.write_fid notin fids:
          send_error(req.tag, "unknown fid")
          continue
        let entry = fids[req.write_fid]
        let count = server.filesystem.write(entry.qid.path, req.write_offset, req.write_data)
        let r = Msg9(mtype: Rwrite, tag: req.tag, write_count: count)
        send_msg(conn, r)
      except FsError as e: send_error(req.tag, e.msg)
      except KeyError as e: send_error(req.tag, e.msg)
      except NinepError: break

    of Tstat:
      try:
        if req.stat_fid notin fids:
          send_error(req.tag, "unknown fid")
          continue
        let entry = fids[req.stat_fid]
        let s = server.filesystem.stat(entry.qid.path)
        let r = Msg9(mtype: Rstat, tag: req.tag, stat_data: s)
        send_msg(conn, r)
      except FsError as e: send_error(req.tag, e.msg)
      except KeyError as e: send_error(req.tag, e.msg)
      except NinepError: break

    of Tclunk:
      try:
        if req.clunk_fid in fids:
          let entry = fids[req.clunk_fid]
          server.filesystem.clunk(entry.qid.path)
          fids.del(req.clunk_fid)
        let r = Msg9(mtype: Rclunk, tag: req.tag)
        send_msg(conn, r)
      except FsError as e: send_error(req.tag, e.msg)
      except KeyError: discard
      except NinepError: break

    of Tremove:
      try:
        if req.remove_fid notin fids:
          send_error(req.tag, "unknown fid")
          continue
        let entry = fids[req.remove_fid]
        server.filesystem.remove(entry.qid.path)
        fids.del(req.remove_fid)
        let r = Msg9(mtype: Rremove, tag: req.tag)
        send_msg(conn, r)
      except FsError as e: send_error(req.tag, e.msg)
      except KeyError as e: send_error(req.tag, e.msg)
      except NinepError: break

    of Tflush:
      let r = Msg9(mtype: Rflush, tag: req.tag)
      try: send_msg(conn, r) except NinepError: break

    else:
      send_error(req.tag, "unsupported message type: " & $req.mtype)

  transport.close(conn)

# =====================================================================================================================
# Server lifecycle
# =====================================================================================================================

proc new_server*(filesystem: FileSystem, msize: uint32 = MaxMsgSize): NinepServer =
  result = NinepServer(filesystem: filesystem, msize: msize)
  result.running.store(false)

proc serve*(server: NinepServer, port: int) =
  ## Start accepting connections. Blocks. Handles one client at a time.
  server.listener = tcp_listen(port)
  server.running.store(true)
  while server.running.load():
    let conn = try: accept(server.listener) except NinepError: break
    handle_session(server, conn)

proc serve_ipc*(server: NinepServer, path: string) =
  server.listener = ipc_listen(path)
  server.running.store(true)
  while server.running.load():
    let conn = try: accept(server.listener) except NinepError: break
    handle_session(server, conn)

proc stop*(server: NinepServer) {.raises: [].} =
  server.running.store(false)
  if server.listener != nil:
    transport.close(server.listener)
