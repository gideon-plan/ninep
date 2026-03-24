## twire.nim -- Wire format unit tests.

{.experimental: "strict_funcs".}

import std/unittest
import ninep/wire

suite "LE integers":
  test "u8 round-trip":
    let enc = encode_u8(42)
    var pos = 0
    check decode_u8(enc, pos) == 42'u8

  test "u16 round-trip":
    let enc = encode_u16(0x1234)
    check uint8(enc[0]) == 0x34  # LE: low byte first
    check uint8(enc[1]) == 0x12
    var pos = 0
    check decode_u16(enc, pos) == 0x1234'u16

  test "u32 round-trip":
    let enc = encode_u32(0xDEADBEEF'u32)
    var pos = 0
    check decode_u32(enc, pos) == 0xDEADBEEF'u32

  test "u64 round-trip":
    let enc = encode_u64(0x0102030405060708'u64)
    var pos = 0
    check decode_u64(enc, pos) == 0x0102030405060708'u64

suite "strings":
  test "string round-trip":
    let enc = encode_str("hello")
    var pos = 0
    check decode_str(enc, pos) == "hello"

  test "empty string":
    let enc = encode_str("")
    var pos = 0
    check decode_str(enc, pos) == ""

  test "data round-trip":
    let enc = encode_data("binary\x00data")
    var pos = 0
    check decode_data(enc, pos) == "binary\x00data"

suite "qid":
  test "qid round-trip":
    let q = Qid(qtype: QtDir, version: 7, path: 12345)
    let enc = encode_qid(q)
    check enc.len == 13
    var pos = 0
    let d = decode_qid(enc, pos)
    check d.qtype == QtDir
    check d.version == 7
    check d.path == 12345

suite "stat":
  test "stat round-trip":
    let s = Stat9(stype: 0, dev: 0, qid: Qid(qtype: QtFile, version: 1, path: 42),
                  mode: 0o644, atime: 1000, mtime: 2000, length: 512,
                  name: "test.txt", uid: "user", gid: "group", muid: "mod")
    let enc = encode_stat(s)
    var pos = 0
    let d = decode_stat(enc, pos)
    check d.name == "test.txt"
    check d.uid == "user"
    check d.gid == "group"
    check d.muid == "mod"
    check d.mode == 0o644'u32
    check d.length == 512
    check d.qid.path == 42
