## transport.nim -- TCP and IPC transport with 9P framing.

{.experimental: "strict_funcs".}

import std/net
import wire, msg

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  NinepConn* = ref object
    sock*: Socket

  NinepListener* = ref object
    sock*: Socket

# =====================================================================================================================
# I/O
# =====================================================================================================================

proc recv_exact(conn: NinepConn, n: int): string {.raises: [NinepError].} =
  result = ""
  while result.len < n:
    let buf = try: conn.sock.recv(n - result.len)
              except CatchableError as e: raise newException(NinepError, "recv: " & e.msg)
    if buf.len == 0:
      raise newException(NinepError, "connection closed")
    result.add(buf)

proc send_all(conn: NinepConn, data: string) {.raises: [NinepError].} =
  try: conn.sock.send(data)
  except CatchableError as e: raise newException(NinepError, "send: " & e.msg)

# =====================================================================================================================
# Message send/recv
# =====================================================================================================================

proc send_msg*(conn: NinepConn, m: Msg9) {.raises: [NinepError].} =
  send_all(conn, encode(m))

proc recv_msg*(conn: NinepConn): Msg9 {.raises: [NinepError].} =
  # Read 4-byte size
  let size_buf = recv_exact(conn, 4)
  var pos = 0
  let size = int(decode_u32(size_buf, pos))
  if size < 7:
    raise newException(NinepError, "message too small: " & $size)
  # Read rest of message
  let body = recv_exact(conn, size - 4)
  let full = size_buf & body
  pos = 0
  result = decode(full, pos)

# =====================================================================================================================
# TCP
# =====================================================================================================================

proc tcp_dial*(host: string, port: int): NinepConn {.raises: [NinepError].} =
  result = NinepConn()
  try:
    result.sock = newSocket()
    result.sock.connect(host, Port(port))
  except CatchableError as e:
    raise newException(NinepError, "tcp dial: " & e.msg)

proc tcp_listen*(port: int): NinepListener {.raises: [NinepError].} =
  result = NinepListener()
  try:
    result.sock = newSocket()
    result.sock.setSockOpt(OptReuseAddr, true)
    result.sock.bindAddr(Port(port))
    result.sock.listen()
  except CatchableError as e:
    raise newException(NinepError, "tcp listen: " & e.msg)

proc accept*(listener: NinepListener): NinepConn {.raises: [NinepError].} =
  result = NinepConn()
  var client: Socket
  try: listener.sock.accept(client)
  except CatchableError as e: raise newException(NinepError, "accept: " & e.msg)
  result.sock = client

# =====================================================================================================================
# IPC
# =====================================================================================================================

proc ipc_dial*(path: string): NinepConn {.raises: [NinepError].} =
  result = NinepConn()
  try:
    result.sock = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
    result.sock.connectUnix(path)
  except CatchableError as e:
    raise newException(NinepError, "ipc dial: " & e.msg)

proc ipc_listen*(path: string): NinepListener {.raises: [NinepError].} =
  result = NinepListener()
  try:
    result.sock = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
    result.sock.bindUnix(path)
    result.sock.listen()
  except CatchableError as e:
    raise newException(NinepError, "ipc listen: " & e.msg)

# =====================================================================================================================
# Close
# =====================================================================================================================

proc close*(conn: NinepConn) {.raises: [].} =
  if conn != nil and conn.sock != nil:
    try: conn.sock.close() except CatchableError: discard

proc close*(listener: NinepListener) {.raises: [].} =
  if listener != nil and listener.sock != nil:
    try: listener.sock.close() except CatchableError: discard
