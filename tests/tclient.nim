## tclient.nim -- Client integration tests against embedded memfs server.

{.experimental: "strict_funcs".}

import std/[unittest, os]
import ninep/[wire, client, server, memfs, lattice]

const test_port = 42000

var g_server: NinepServer

proc server_thread_a() {.thread.} =
  {.gcsafe.}:
    g_server = new_server(new_memfs())
    g_server.serve(test_port)

proc server_thread_b() {.thread.} =
  {.gcsafe.}:
    g_server = new_server(new_memfs())
    g_server.serve(test_port + 1)

suite "client-server":
  test "connect and stat root":
    var t: Thread[void]
    createThread(t, server_thread_a)
    sleep(300)

    let c = connect("127.0.0.1", test_port)
    check c.root_qid.qtype == QtDir

    let sr = c.stat(c.root_fid)
    check sr.is_good
    check sr.val.name == "/"

    client.close(c)

  test "create file, write, read":
    var t: Thread[void]
    createThread(t, server_thread_b)
    sleep(300)

    let c = connect("127.0.0.1", test_port + 1)

    # Create a file in root
    let cr = c.create(c.root_fid, "hello.txt", 0o644, Ordwr)
    check cr.is_good

    # Write to it (root_fid is now the created file's fid after Tcreate)
    let wr = c.write(c.root_fid, "hello 9p!")
    check wr.is_good
    check wr.val == 9

    # Read it back
    let rr = c.read(c.root_fid, 0, 4096)
    check rr.is_good
    check rr.val == "hello 9p!"

    client.close(c)
