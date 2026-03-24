## tpassthrough.nim -- Passthrough filesystem integration tests.

{.experimental: "strict_funcs".}

import std/[unittest, os]
import ninep/[wire, client, server, passthrough, lattice]

const pt_port = 42010
const test_dir = "/tmp/ninep_test"

var g_pt_server: NinepServer

proc pt_server_thread() {.thread.} =
  {.gcsafe.}:
    g_pt_server = new_server(new_passthrough(test_dir))
    g_pt_server.serve(pt_port)

suite "passthrough":
  setup:
    createDir(test_dir)
    writeFile(test_dir / "exist.txt", "existing content")

  test "read existing file":
    var t: Thread[void]
    createThread(t, pt_server_thread)
    sleep(300)

    let c = connect("127.0.0.1", pt_port)

    # Walk to the file
    let wr = c.walk(@["exist.txt"])
    check wr.is_good
    let (fid, qids) = wr.val
    check qids.len == 1
    check qids[0].qtype == QtFile

    # Open
    let or2 = c.open(fid, Oread)
    check or2.is_good

    # Read
    let rr = c.read(fid, 0, 4096)
    check rr.is_good
    check rr.val == "existing content"

    discard c.clunk(fid)
    client.close(c)

  teardown:
    removeDir(test_dir)
