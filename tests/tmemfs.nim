## tmemfs.nim -- In-memory filesystem tests.

{.experimental: "strict_funcs".}

import std/unittest
import ninep/[wire, fs, memfs]

suite "memfs":
  test "attach returns root qid":
    let mfs = new_memfs()
    let (qid, name) = mfs.attach("user", "")
    check qid.qtype == QtDir
    check name == "/"

  test "create file and read back":
    let mfs = new_memfs()
    let (root_qid, _) = mfs.attach("user", "")
    let (fqid, _) = mfs.create(root_qid.path, "test.txt", 0o644, Ordwr)
    check fqid.qtype == QtFile
    let written = mfs.write(fqid.path, 0, "hello world")
    check written == 11
    let data = mfs.read(fqid.path, 0, 4096)
    check data == "hello world"

  test "create directory":
    let mfs = new_memfs()
    let (root_qid, _) = mfs.attach("user", "")
    let (dqid, _) = mfs.create(root_qid.path, "subdir", DmDir or 0o755, Oread)
    check dqid.qtype == QtDir

  test "walk to file":
    let mfs = new_memfs()
    let (root_qid, _) = mfs.attach("user", "")
    discard mfs.create(root_qid.path, "a.txt", 0o644, Ordwr)
    let qids = mfs.walk(@["a.txt"])
    check qids.len == 1
    check qids[0].qtype == QtFile

  test "walk through directory":
    let mfs = new_memfs()
    let (root_qid, _) = mfs.attach("user", "")
    let (dqid, _) = mfs.create(root_qid.path, "dir", DmDir or 0o755, Oread)
    discard mfs.create(dqid.path, "file.txt", 0o644, Ordwr)
    let qids = mfs.walk(@["dir", "file.txt"])
    check qids.len == 2
    check qids[0].qtype == QtDir
    check qids[1].qtype == QtFile

  test "stat file":
    let mfs = new_memfs()
    let (root_qid, _) = mfs.attach("user", "")
    let (fqid, _) = mfs.create(root_qid.path, "s.txt", 0o644, Ordwr)
    discard mfs.write(fqid.path, 0, "data")
    let s = mfs.stat(fqid.path)
    check s.name == "s.txt"
    check s.length == 4

  test "remove file":
    let mfs = new_memfs()
    let (root_qid, _) = mfs.attach("user", "")
    let (fqid, _) = mfs.create(root_qid.path, "del.txt", 0o644, Ordwr)
    mfs.remove(fqid.path)
    expect FsError:
      discard mfs.stat(fqid.path)

  test "remove non-empty directory fails":
    let mfs = new_memfs()
    let (root_qid, _) = mfs.attach("user", "")
    let (dqid, _) = mfs.create(root_qid.path, "dir", DmDir or 0o755, Oread)
    discard mfs.create(dqid.path, "child.txt", 0o644, Ordwr)
    expect FsError:
      mfs.remove(dqid.path)

  test "write at offset":
    let mfs = new_memfs()
    let (root_qid, _) = mfs.attach("user", "")
    let (fqid, _) = mfs.create(root_qid.path, "off.txt", 0o644, Ordwr)
    discard mfs.write(fqid.path, 0, "hello")
    discard mfs.write(fqid.path, 5, " world")
    let data = mfs.read(fqid.path, 0, 4096)
    check data == "hello world"

  test "read at offset":
    let mfs = new_memfs()
    let (root_qid, _) = mfs.attach("user", "")
    let (fqid, _) = mfs.create(root_qid.path, "r.txt", 0o644, Ordwr)
    discard mfs.write(fqid.path, 0, "abcdef")
    let data = mfs.read(fqid.path, 3, 10)
    check data == "def"

  test "read past end returns empty":
    let mfs = new_memfs()
    let (root_qid, _) = mfs.attach("user", "")
    let (fqid, _) = mfs.create(root_qid.path, "e.txt", 0o644, Ordwr)
    discard mfs.write(fqid.path, 0, "short")
    let data = mfs.read(fqid.path, 100, 10)
    check data == ""
