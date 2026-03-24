## msg.nim -- 9P2000 + 9P2000.L message types. Encode/decode.
##
## Each message is: 4-byte LE size (including size) + 1-byte type + 2-byte tag + body.

{.experimental: "strict_funcs".}

import wire

# =====================================================================================================================
# Message type
# =====================================================================================================================

type
  Msg9* = object
    tag*: uint16
    case mtype*: uint8
    # 9P2000 base
    of Tversion, Rversion:
      msize*: uint32
      version*: string
    of Tauth:
      auth_afid*: uint32
      auth_uname*: string
      auth_aname*: string
    of Rauth:
      auth_aqid*: Qid
    of Tattach:
      attach_fid*: uint32
      attach_afid*: uint32
      attach_uname*: string
      attach_aname*: string
    of Rattach:
      attach_qid*: Qid
    of Rerror:
      ename*: string
    of Tflush:
      flush_oldtag*: uint16
    of Rflush:
      discard
    of Twalk:
      walk_fid*: uint32
      walk_newfid*: uint32
      walk_names*: seq[string]
    of Rwalk:
      walk_qids*: seq[Qid]
    of Topen:
      open_fid*: uint32
      open_mode*: uint8
    of Ropen:
      open_qid*: Qid
      open_iounit*: uint32
    of Tcreate:
      create_fid*: uint32
      create_name*: string
      create_perm*: uint32
      create_mode*: uint8
    of Rcreate:
      created_qid*: Qid
      created_iounit*: uint32
    of Tread:
      read_fid*: uint32
      read_offset*: uint64
      read_count*: uint32
    of Rread:
      read_data*: string
    of Twrite:
      write_fid*: uint32
      write_offset*: uint64
      write_data*: string
    of Rwrite:
      write_count*: uint32
    of Tclunk:
      clunk_fid*: uint32
    of Rclunk:
      discard
    of Tremove:
      remove_fid*: uint32
    of Rremove:
      discard
    of Tstat:
      stat_fid*: uint32
    of Rstat:
      stat_data*: Stat9
    of Twstat:
      wstat_fid*: uint32
      wstat_data*: Stat9
    of Rwstat:
      discard
    # 9P2000.L
    of Rlerror:
      lerror_ecode*: uint32
    of Tgetattr:
      getattr_fid*: uint32
      getattr_mask*: uint64
    of Rgetattr:
      rgetattr_valid*: uint64
      rgetattr_qid*: Qid
      rgetattr_mode*: uint32
      rgetattr_uid*: uint32
      rgetattr_gid*: uint32
      rgetattr_nlink*: uint64
      rgetattr_rdev*: uint64
      rgetattr_size*: uint64
      rgetattr_blksize*: uint64
      rgetattr_blocks*: uint64
      rgetattr_atime_sec*: uint64
      rgetattr_atime_nsec*: uint64
      rgetattr_mtime_sec*: uint64
      rgetattr_mtime_nsec*: uint64
      rgetattr_ctime_sec*: uint64
      rgetattr_ctime_nsec*: uint64
      rgetattr_btime_sec*: uint64
      rgetattr_btime_nsec*: uint64
      rgetattr_gen*: uint64
      rgetattr_data_version*: uint64
    of Tsetattr:
      setattr_fid*: uint32
      setattr_valid*: uint32
      setattr_mode*: uint32
      setattr_uid*: uint32
      setattr_gid*: uint32
      setattr_size*: uint64
      setattr_atime_sec*: uint64
      setattr_atime_nsec*: uint64
      setattr_mtime_sec*: uint64
      setattr_mtime_nsec*: uint64
    of Rsetattr:
      discard
    of Treaddir:
      readdir_fid*: uint32
      readdir_offset*: uint64
      readdir_count*: uint32
    of Rreaddir:
      readdir_data*: string
    of Tmkdir:
      mkdir_dfid*: uint32
      mkdir_name*: string
      mkdir_mode*: uint32
      mkdir_gid_val*: uint32
    of Rmkdir:
      mkdir_qid*: Qid
    of Trenameat:
      renameat_olddirfid*: uint32
      renameat_oldname*: string
      renameat_newdirfid*: uint32
      renameat_newname*: string
    of Rrenameat:
      discard
    of Tunlinkat:
      unlinkat_dirfid*: uint32
      unlinkat_name*: string
      unlinkat_flags*: uint32
    of Runlinkat:
      discard
    of Tlopen:
      lopen_fid*: uint32
      lopen_flags*: uint32
    of Rlopen:
      lopen_qid*: Qid
      lopen_iounit*: uint32
    of Tlcreate:
      lcreate_fid*: uint32
      lcreate_name*: string
      lcreate_flags*: uint32
      lcreate_mode*: uint32
      lcreate_gid_val*: uint32
    of Rlcreate:
      lcreate_qid*: Qid
      lcreate_iounit*: uint32
    of Tsymlink:
      symlink_dfid*: uint32
      symlink_name*: string
      symlink_target*: string
      symlink_gid_val*: uint32
    of Rsymlink:
      symlink_qid*: Qid
    of Tlink:
      link_dfid*: uint32
      link_fid*: uint32
      link_name*: string
    of Rlink:
      discard
    of Tfsync:
      fsync_fid*: uint32
    of Rfsync:
      discard
    else:
      raw_body*: string

# =====================================================================================================================
# Encode
# =====================================================================================================================

proc encode_body(m: Msg9): string {.raises: [NinepError].} =
  result = ""
  case m.mtype
  of Tversion, Rversion:
    result.add(encode_u32(m.msize))
    result.add(encode_str(m.version))
  of Tauth:
    result.add(encode_u32(m.auth_afid))
    result.add(encode_str(m.auth_uname))
    result.add(encode_str(m.auth_aname))
  of Rauth:
    result.add(encode_qid(m.auth_aqid))
  of Tattach:
    result.add(encode_u32(m.attach_fid))
    result.add(encode_u32(m.attach_afid))
    result.add(encode_str(m.attach_uname))
    result.add(encode_str(m.attach_aname))
  of Rattach:
    result.add(encode_qid(m.attach_qid))
  of Rerror:
    result.add(encode_str(m.ename))
  of Tflush:
    result.add(encode_u16(m.flush_oldtag))
  of Rflush:
    discard
  of Twalk:
    result.add(encode_u32(m.walk_fid))
    result.add(encode_u32(m.walk_newfid))
    result.add(encode_u16(uint16(m.walk_names.len)))
    for name in m.walk_names:
      result.add(encode_str(name))
  of Rwalk:
    result.add(encode_u16(uint16(m.walk_qids.len)))
    for q in m.walk_qids:
      result.add(encode_qid(q))
  of Topen:
    result.add(encode_u32(m.open_fid))
    result.add(encode_u8(m.open_mode))
  of Ropen:
    result.add(encode_qid(m.open_qid))
    result.add(encode_u32(m.open_iounit))
  of Tcreate:
    result.add(encode_u32(m.create_fid))
    result.add(encode_str(m.create_name))
    result.add(encode_u32(m.create_perm))
    result.add(encode_u8(m.create_mode))
  of Rcreate:
    result.add(encode_qid(m.created_qid))
    result.add(encode_u32(m.created_iounit))
  of Tread:
    result.add(encode_u32(m.read_fid))
    result.add(encode_u64(m.read_offset))
    result.add(encode_u32(m.read_count))
  of Rread:
    result.add(encode_data(m.read_data))
  of Twrite:
    result.add(encode_u32(m.write_fid))
    result.add(encode_u64(m.write_offset))
    result.add(encode_data(m.write_data))
  of Rwrite:
    result.add(encode_u32(m.write_count))
  of Tclunk:
    result.add(encode_u32(m.clunk_fid))
  of Rclunk:
    discard
  of Tremove:
    result.add(encode_u32(m.remove_fid))
  of Rremove:
    discard
  of Tstat:
    result.add(encode_u32(m.stat_fid))
  of Rstat:
    let stat_body = encode_stat(m.stat_data)
    # Rstat wraps stat in 2-byte size + stat + 2-byte size + stat
    result.add(encode_u16(uint16(stat_body.len + 2)))
    result.add(encode_u16(uint16(stat_body.len)))
    result.add(stat_body)
  of Twstat:
    result.add(encode_u32(m.wstat_fid))
    let stat_body = encode_stat(m.wstat_data)
    result.add(encode_u16(uint16(stat_body.len + 2)))
    result.add(encode_u16(uint16(stat_body.len)))
    result.add(stat_body)
  of Rwstat:
    discard
  # 9P2000.L
  of Rlerror:
    result.add(encode_u32(m.lerror_ecode))
  of Tgetattr:
    result.add(encode_u32(m.getattr_fid))
    result.add(encode_u64(m.getattr_mask))
  of Rgetattr:
    result.add(encode_u64(m.rgetattr_valid))
    result.add(encode_qid(m.rgetattr_qid))
    result.add(encode_u32(m.rgetattr_mode))
    result.add(encode_u32(m.rgetattr_uid))
    result.add(encode_u32(m.rgetattr_gid))
    result.add(encode_u64(m.rgetattr_nlink))
    result.add(encode_u64(m.rgetattr_rdev))
    result.add(encode_u64(m.rgetattr_size))
    result.add(encode_u64(m.rgetattr_blksize))
    result.add(encode_u64(m.rgetattr_blocks))
    result.add(encode_u64(m.rgetattr_atime_sec))
    result.add(encode_u64(m.rgetattr_atime_nsec))
    result.add(encode_u64(m.rgetattr_mtime_sec))
    result.add(encode_u64(m.rgetattr_mtime_nsec))
    result.add(encode_u64(m.rgetattr_ctime_sec))
    result.add(encode_u64(m.rgetattr_ctime_nsec))
    result.add(encode_u64(m.rgetattr_btime_sec))
    result.add(encode_u64(m.rgetattr_btime_nsec))
    result.add(encode_u64(m.rgetattr_gen))
    result.add(encode_u64(m.rgetattr_data_version))
  of Tsetattr:
    result.add(encode_u32(m.setattr_fid))
    result.add(encode_u32(m.setattr_valid))
    result.add(encode_u32(m.setattr_mode))
    result.add(encode_u32(m.setattr_uid))
    result.add(encode_u32(m.setattr_gid))
    result.add(encode_u64(m.setattr_size))
    result.add(encode_u64(m.setattr_atime_sec))
    result.add(encode_u64(m.setattr_atime_nsec))
    result.add(encode_u64(m.setattr_mtime_sec))
    result.add(encode_u64(m.setattr_mtime_nsec))
  of Rsetattr:
    discard
  of Treaddir:
    result.add(encode_u32(m.readdir_fid))
    result.add(encode_u64(m.readdir_offset))
    result.add(encode_u32(m.readdir_count))
  of Rreaddir:
    result.add(encode_data(m.readdir_data))
  of Tmkdir:
    result.add(encode_u32(m.mkdir_dfid))
    result.add(encode_str(m.mkdir_name))
    result.add(encode_u32(m.mkdir_mode))
    result.add(encode_u32(m.mkdir_gid_val))
  of Rmkdir:
    result.add(encode_qid(m.mkdir_qid))
  of Trenameat:
    result.add(encode_u32(m.renameat_olddirfid))
    result.add(encode_str(m.renameat_oldname))
    result.add(encode_u32(m.renameat_newdirfid))
    result.add(encode_str(m.renameat_newname))
  of Rrenameat:
    discard
  of Tunlinkat:
    result.add(encode_u32(m.unlinkat_dirfid))
    result.add(encode_str(m.unlinkat_name))
    result.add(encode_u32(m.unlinkat_flags))
  of Runlinkat:
    discard
  of Tlopen:
    result.add(encode_u32(m.lopen_fid))
    result.add(encode_u32(m.lopen_flags))
  of Rlopen:
    result.add(encode_qid(m.lopen_qid))
    result.add(encode_u32(m.lopen_iounit))
  of Tlcreate:
    result.add(encode_u32(m.lcreate_fid))
    result.add(encode_str(m.lcreate_name))
    result.add(encode_u32(m.lcreate_flags))
    result.add(encode_u32(m.lcreate_mode))
    result.add(encode_u32(m.lcreate_gid_val))
  of Rlcreate:
    result.add(encode_qid(m.lcreate_qid))
    result.add(encode_u32(m.lcreate_iounit))
  of Tsymlink:
    result.add(encode_u32(m.symlink_dfid))
    result.add(encode_str(m.symlink_name))
    result.add(encode_str(m.symlink_target))
    result.add(encode_u32(m.symlink_gid_val))
  of Rsymlink:
    result.add(encode_qid(m.symlink_qid))
  of Tlink:
    result.add(encode_u32(m.link_dfid))
    result.add(encode_u32(m.link_fid))
    result.add(encode_str(m.link_name))
  of Rlink:
    discard
  of Tfsync:
    result.add(encode_u32(m.fsync_fid))
  of Rfsync:
    discard
  else:
    result.add(m.raw_body)

proc encode*(m: Msg9): string {.raises: [NinepError].} =
  ## Encode a 9P message to wire format (size + type + tag + body).
  let body = encode_body(m)
  let size = uint32(4 + 1 + 2 + body.len)  # size field + type + tag + body
  result = encode_u32(size) & encode_u8(m.mtype) & encode_u16(m.tag) & body

# =====================================================================================================================
# Decode
# =====================================================================================================================

proc decode*(buf: string, pos: var int): Msg9 {.raises: [NinepError].} =
  ## Decode one 9P message from buf at pos. Advances pos.
  let size = int(decode_u32(buf, pos))
  if pos + size - 4 > buf.len:
    raise newException(NinepError, "message extends beyond buffer")
  let end_pos = pos + size - 4  # size includes the 4-byte size field
  let mtype = decode_u8(buf, pos)
  let tag = decode_u16(buf, pos)

  case mtype
  of Tversion, Rversion:
    let msize = decode_u32(buf, pos)
    let ver = decode_str(buf, pos)
    result = Msg9(mtype: mtype, tag: tag, msize: msize, version: ver)
  of Tauth:
    result = Msg9(mtype: mtype, tag: tag, auth_afid: decode_u32(buf, pos),
                  auth_uname: decode_str(buf, pos), auth_aname: decode_str(buf, pos))
  of Rauth:
    result = Msg9(mtype: mtype, tag: tag, auth_aqid: decode_qid(buf, pos))
  of Tattach:
    result = Msg9(mtype: mtype, tag: tag, attach_fid: decode_u32(buf, pos),
                  attach_afid: decode_u32(buf, pos), attach_uname: decode_str(buf, pos),
                  attach_aname: decode_str(buf, pos))
  of Rattach:
    result = Msg9(mtype: mtype, tag: tag, attach_qid: decode_qid(buf, pos))
  of Rerror:
    result = Msg9(mtype: mtype, tag: tag, ename: decode_str(buf, pos))
  of Tflush:
    result = Msg9(mtype: mtype, tag: tag, flush_oldtag: decode_u16(buf, pos))
  of Rflush:
    result = Msg9(mtype: mtype, tag: tag)
  of Twalk:
    let fid = decode_u32(buf, pos)
    let newfid = decode_u32(buf, pos)
    let nwname = int(decode_u16(buf, pos))
    var names: seq[string] = @[]
    for i in 0 ..< nwname:
      names.add(decode_str(buf, pos))
    result = Msg9(mtype: mtype, tag: tag, walk_fid: fid, walk_newfid: newfid, walk_names: names)
  of Rwalk:
    let nwqid = int(decode_u16(buf, pos))
    var qids: seq[Qid] = @[]
    for i in 0 ..< nwqid:
      qids.add(decode_qid(buf, pos))
    result = Msg9(mtype: mtype, tag: tag, walk_qids: qids)
  of Topen:
    result = Msg9(mtype: mtype, tag: tag, open_fid: decode_u32(buf, pos), open_mode: decode_u8(buf, pos))
  of Ropen:
    result = Msg9(mtype: mtype, tag: tag, open_qid: decode_qid(buf, pos), open_iounit: decode_u32(buf, pos))
  of Tcreate:
    result = Msg9(mtype: mtype, tag: tag, create_fid: decode_u32(buf, pos),
                  create_name: decode_str(buf, pos), create_perm: decode_u32(buf, pos),
                  create_mode: decode_u8(buf, pos))
  of Rcreate:
    result = Msg9(mtype: mtype, tag: tag, created_qid: decode_qid(buf, pos),
                  created_iounit: decode_u32(buf, pos))
  of Tread:
    result = Msg9(mtype: mtype, tag: tag, read_fid: decode_u32(buf, pos),
                  read_offset: decode_u64(buf, pos), read_count: decode_u32(buf, pos))
  of Rread:
    result = Msg9(mtype: mtype, tag: tag, read_data: decode_data(buf, pos))
  of Twrite:
    let fid = decode_u32(buf, pos)
    let offset = decode_u64(buf, pos)
    let data = decode_data(buf, pos)
    result = Msg9(mtype: mtype, tag: tag, write_fid: fid, write_offset: offset, write_data: data)
  of Rwrite:
    result = Msg9(mtype: mtype, tag: tag, write_count: decode_u32(buf, pos))
  of Tclunk:
    result = Msg9(mtype: mtype, tag: tag, clunk_fid: decode_u32(buf, pos))
  of Rclunk:
    result = Msg9(mtype: mtype, tag: tag)
  of Tremove:
    result = Msg9(mtype: mtype, tag: tag, remove_fid: decode_u32(buf, pos))
  of Rremove:
    result = Msg9(mtype: mtype, tag: tag)
  of Tstat:
    result = Msg9(mtype: mtype, tag: tag, stat_fid: decode_u32(buf, pos))
  of Rstat:
    discard decode_u16(buf, pos)  # outer size
    discard decode_u16(buf, pos)  # inner size
    result = Msg9(mtype: mtype, tag: tag, stat_data: decode_stat(buf, pos))
  of Twstat:
    let fid = decode_u32(buf, pos)
    discard decode_u16(buf, pos)  # outer size
    discard decode_u16(buf, pos)  # inner size
    result = Msg9(mtype: mtype, tag: tag, wstat_fid: fid, wstat_data: decode_stat(buf, pos))
  of Rwstat:
    result = Msg9(mtype: mtype, tag: tag)
  # 9P2000.L
  of Rlerror:
    result = Msg9(mtype: mtype, tag: tag, lerror_ecode: decode_u32(buf, pos))
  of Tgetattr:
    result = Msg9(mtype: mtype, tag: tag, getattr_fid: decode_u32(buf, pos),
                  getattr_mask: decode_u64(buf, pos))
  of Rgetattr:
    result = Msg9(mtype: Rgetattr, tag: tag)
    result.rgetattr_valid = decode_u64(buf, pos)
    result.rgetattr_qid = decode_qid(buf, pos)
    result.rgetattr_mode = decode_u32(buf, pos)
    result.rgetattr_uid = decode_u32(buf, pos)
    result.rgetattr_gid = decode_u32(buf, pos)
    result.rgetattr_nlink = decode_u64(buf, pos)
    result.rgetattr_rdev = decode_u64(buf, pos)
    result.rgetattr_size = decode_u64(buf, pos)
    result.rgetattr_blksize = decode_u64(buf, pos)
    result.rgetattr_blocks = decode_u64(buf, pos)
    result.rgetattr_atime_sec = decode_u64(buf, pos)
    result.rgetattr_atime_nsec = decode_u64(buf, pos)
    result.rgetattr_mtime_sec = decode_u64(buf, pos)
    result.rgetattr_mtime_nsec = decode_u64(buf, pos)
    result.rgetattr_ctime_sec = decode_u64(buf, pos)
    result.rgetattr_ctime_nsec = decode_u64(buf, pos)
    result.rgetattr_btime_sec = decode_u64(buf, pos)
    result.rgetattr_btime_nsec = decode_u64(buf, pos)
    result.rgetattr_gen = decode_u64(buf, pos)
    result.rgetattr_data_version = decode_u64(buf, pos)
  of Tsetattr:
    result = Msg9(mtype: Tsetattr, tag: tag)
    result.setattr_fid = decode_u32(buf, pos)
    result.setattr_valid = decode_u32(buf, pos)
    result.setattr_mode = decode_u32(buf, pos)
    result.setattr_uid = decode_u32(buf, pos)
    result.setattr_gid = decode_u32(buf, pos)
    result.setattr_size = decode_u64(buf, pos)
    result.setattr_atime_sec = decode_u64(buf, pos)
    result.setattr_atime_nsec = decode_u64(buf, pos)
    result.setattr_mtime_sec = decode_u64(buf, pos)
    result.setattr_mtime_nsec = decode_u64(buf, pos)
  of Rsetattr:
    result = Msg9(mtype: mtype, tag: tag)
  of Treaddir:
    result = Msg9(mtype: mtype, tag: tag, readdir_fid: decode_u32(buf, pos),
                  readdir_offset: decode_u64(buf, pos), readdir_count: decode_u32(buf, pos))
  of Rreaddir:
    result = Msg9(mtype: mtype, tag: tag, readdir_data: decode_data(buf, pos))
  of Tmkdir:
    result = Msg9(mtype: mtype, tag: tag, mkdir_dfid: decode_u32(buf, pos),
                  mkdir_name: decode_str(buf, pos), mkdir_mode: decode_u32(buf, pos),
                  mkdir_gid_val: decode_u32(buf, pos))
  of Rmkdir:
    result = Msg9(mtype: mtype, tag: tag, mkdir_qid: decode_qid(buf, pos))
  of Trenameat:
    result = Msg9(mtype: mtype, tag: tag, renameat_olddirfid: decode_u32(buf, pos),
                  renameat_oldname: decode_str(buf, pos), renameat_newdirfid: decode_u32(buf, pos),
                  renameat_newname: decode_str(buf, pos))
  of Rrenameat:
    result = Msg9(mtype: mtype, tag: tag)
  of Tunlinkat:
    result = Msg9(mtype: mtype, tag: tag, unlinkat_dirfid: decode_u32(buf, pos),
                  unlinkat_name: decode_str(buf, pos), unlinkat_flags: decode_u32(buf, pos))
  of Runlinkat:
    result = Msg9(mtype: mtype, tag: tag)
  of Tlopen:
    result = Msg9(mtype: mtype, tag: tag, lopen_fid: decode_u32(buf, pos),
                  lopen_flags: decode_u32(buf, pos))
  of Rlopen:
    result = Msg9(mtype: mtype, tag: tag, lopen_qid: decode_qid(buf, pos),
                  lopen_iounit: decode_u32(buf, pos))
  of Tlcreate:
    result = Msg9(mtype: mtype, tag: tag, lcreate_fid: decode_u32(buf, pos),
                  lcreate_name: decode_str(buf, pos), lcreate_flags: decode_u32(buf, pos),
                  lcreate_mode: decode_u32(buf, pos), lcreate_gid_val: decode_u32(buf, pos))
  of Rlcreate:
    result = Msg9(mtype: mtype, tag: tag, lcreate_qid: decode_qid(buf, pos),
                  lcreate_iounit: decode_u32(buf, pos))
  of Tsymlink:
    result = Msg9(mtype: mtype, tag: tag, symlink_dfid: decode_u32(buf, pos),
                  symlink_name: decode_str(buf, pos), symlink_target: decode_str(buf, pos),
                  symlink_gid_val: decode_u32(buf, pos))
  of Rsymlink:
    result = Msg9(mtype: mtype, tag: tag, symlink_qid: decode_qid(buf, pos))
  of Tlink:
    result = Msg9(mtype: mtype, tag: tag, link_dfid: decode_u32(buf, pos),
                  link_fid: decode_u32(buf, pos), link_name: decode_str(buf, pos))
  of Rlink:
    result = Msg9(mtype: mtype, tag: tag)
  of Tfsync:
    result = Msg9(mtype: mtype, tag: tag, fsync_fid: decode_u32(buf, pos))
  of Rfsync:
    result = Msg9(mtype: mtype, tag: tag)
  else:
    let remaining = end_pos - pos
    var raw = ""
    if remaining > 0:
      raw = buf[pos ..< end_pos]
    result = Msg9(mtype: mtype, tag: tag, raw_body: raw)
    pos = end_pos
