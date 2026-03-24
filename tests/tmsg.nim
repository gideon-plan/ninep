## tmsg.nim -- Message encode/decode round-trip tests.

{.experimental: "strict_funcs".}

import std/unittest
import ninep/[wire, msg]

suite "9P2000 messages":
  test "Tversion/Rversion round-trip":
    let m = Msg9(mtype: Tversion, tag: NoTag, msize: 8192, version: "9P2000")
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.mtype == Tversion
    check d.msize == 8192
    check d.version == "9P2000"

  test "Tattach/Rattach round-trip":
    let m = Msg9(mtype: Tattach, tag: 1, attach_fid: 0, attach_afid: NoFid,
                 attach_uname: "user", attach_aname: "")
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.mtype == Tattach
    check d.attach_fid == 0
    check d.attach_uname == "user"

  test "Rerror round-trip":
    let m = Msg9(mtype: Rerror, tag: 5, ename: "file not found")
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.mtype == Rerror
    check d.ename == "file not found"

  test "Twalk/Rwalk round-trip":
    let m = Msg9(mtype: Twalk, tag: 2, walk_fid: 0, walk_newfid: 1,
                 walk_names: @["dir", "file.txt"])
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.walk_names == @["dir", "file.txt"]

    let q1 = Qid(qtype: QtDir, version: 0, path: 1)
    let q2 = Qid(qtype: QtFile, version: 0, path: 2)
    let r = Msg9(mtype: Rwalk, tag: 2, walk_qids: @[q1, q2])
    let renc = encode(r)
    var rpos = 0
    let rd = decode(renc, rpos)
    check rd.walk_qids.len == 2
    check rd.walk_qids[0].qtype == QtDir
    check rd.walk_qids[1].path == 2

  test "Topen/Ropen round-trip":
    let m = Msg9(mtype: Topen, tag: 3, open_fid: 1, open_mode: Oread)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.open_fid == 1
    check d.open_mode == Oread

  test "Tread/Rread round-trip":
    let m = Msg9(mtype: Tread, tag: 4, read_fid: 1, read_offset: 0, read_count: 4096)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.read_count == 4096

    let r = Msg9(mtype: Rread, tag: 4, read_data: "file content here")
    let renc = encode(r)
    var rpos = 0
    let rd = decode(renc, rpos)
    check rd.read_data == "file content here"

  test "Twrite/Rwrite round-trip":
    let m = Msg9(mtype: Twrite, tag: 5, write_fid: 1, write_offset: 0, write_data: "new data")
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.write_data == "new data"

    let r = Msg9(mtype: Rwrite, tag: 5, write_count: 8)
    let renc = encode(r)
    var rpos = 0
    let rd = decode(renc, rpos)
    check rd.write_count == 8

  test "Tcreate/Rcreate round-trip":
    let m = Msg9(mtype: Tcreate, tag: 6, create_fid: 0, create_name: "new.txt",
                 create_perm: 0o644, create_mode: Ordwr)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.create_name == "new.txt"
    check d.create_perm == 0o644'u32

  test "Tstat/Rstat round-trip":
    let s = Stat9(qid: Qid(qtype: QtFile, version: 1, path: 10), mode: 0o644,
                  name: "f.txt", length: 100, uid: "u", gid: "g", muid: "m")
    let r = Msg9(mtype: Rstat, tag: 7, stat_data: s)
    let enc = encode(r)
    var pos = 0
    let d = decode(enc, pos)
    check d.stat_data.name == "f.txt"
    check d.stat_data.length == 100

  test "Tclunk/Rclunk round-trip":
    let m = Msg9(mtype: Tclunk, tag: 8, clunk_fid: 5)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.clunk_fid == 5

  test "Tremove/Rremove round-trip":
    let m = Msg9(mtype: Tremove, tag: 9, remove_fid: 3)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.remove_fid == 3

  test "Tflush/Rflush round-trip":
    let m = Msg9(mtype: Tflush, tag: 10, flush_oldtag: 5)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.flush_oldtag == 5

suite "9P2000.L messages":
  test "Rlerror round-trip":
    let m = Msg9(mtype: Rlerror, tag: 1, lerror_ecode: 2)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.lerror_ecode == 2

  test "Tmkdir/Rmkdir round-trip":
    let m = Msg9(mtype: Tmkdir, tag: 2, mkdir_dfid: 0, mkdir_name: "subdir",
                 mkdir_mode: 0o755, mkdir_gid_val: 0)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.mkdir_name == "subdir"

  test "Tunlinkat/Runlinkat round-trip":
    let m = Msg9(mtype: Tunlinkat, tag: 3, unlinkat_dirfid: 0,
                 unlinkat_name: "old.txt", unlinkat_flags: 0)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.unlinkat_name == "old.txt"

  test "Tlopen/Rlopen round-trip":
    let m = Msg9(mtype: Tlopen, tag: 4, lopen_fid: 1, lopen_flags: 0)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.lopen_fid == 1

  test "Treaddir/Rreaddir round-trip":
    let m = Msg9(mtype: Treaddir, tag: 5, readdir_fid: 0, readdir_offset: 0,
                 readdir_count: 4096)
    let enc = encode(m)
    var pos = 0
    let d = decode(enc, pos)
    check d.readdir_count == 4096
