## wire.nim -- 9P wire format: LE integers, qid, stat, string encoding.
##
## 9P uses little-endian byte order for all integers.
## Messages: 4-byte LE size (including size field) + 1-byte type + 2-byte tag + body.

{.experimental: "strict_funcs".}

# =====================================================================================================================
# Errors
# =====================================================================================================================

type
  NinepError* = object of CatchableError

# =====================================================================================================================
# Constants
# =====================================================================================================================

const
  MaxMsgSize* = 8192 + 24'u32  ## Default max message size
  NoTag* = 0xFFFF'u16          ## Tag for Tversion/Rversion
  NoFid* = 0xFFFFFFFF'u32      ## Invalid fid

  # 9P2000 message types
  Tversion* = 100'u8
  Rversion* = 101'u8
  Tauth*    = 102'u8
  Rauth*    = 103'u8
  Tattach*  = 104'u8
  Rattach*  = 105'u8
  Rerror*   = 107'u8
  Tflush*   = 108'u8
  Rflush*   = 109'u8
  Twalk*    = 110'u8
  Rwalk*    = 111'u8
  Topen*    = 112'u8
  Ropen*    = 113'u8
  Tcreate*  = 114'u8
  Rcreate*  = 115'u8
  Tread*    = 116'u8
  Rread*    = 117'u8
  Twrite*   = 118'u8
  Rwrite*   = 119'u8
  Tclunk*   = 120'u8
  Rclunk*   = 121'u8
  Tremove*  = 122'u8
  Rremove*  = 123'u8
  Tstat*    = 124'u8
  Rstat*    = 125'u8
  Twstat*   = 126'u8
  Rwstat*   = 127'u8

  # 9P2000.L message types
  Tlerror*     = 6'u8
  Rlerror*     = 7'u8
  Tstatfs*     = 8'u8
  Rstatfs*     = 9'u8
  Tlopen*      = 12'u8
  Rlopen*      = 13'u8
  Tlcreate*    = 14'u8
  Rlcreate*    = 15'u8
  Tsymlink*    = 16'u8
  Rsymlink*    = 17'u8
  Tmknod*      = 18'u8
  Rmknod*      = 19'u8
  Trename*     = 20'u8
  Rrename*     = 21'u8
  Treadlink*   = 22'u8
  Rreadlink*   = 23'u8
  Tgetattr*    = 24'u8
  Rgetattr*    = 25'u8
  Tsetattr*    = 26'u8
  Rsetattr*    = 27'u8
  Txattrwalk*  = 30'u8
  Rxattrwalk*  = 31'u8
  Txattrcreate* = 32'u8
  Rxattrcreate* = 33'u8
  Treaddir*    = 40'u8
  Rreaddir*    = 41'u8
  Tfsync*      = 50'u8
  Rfsync*      = 51'u8
  Tlock*       = 52'u8
  Rlock*       = 53'u8
  Tgetlock*    = 54'u8
  Rgetlock*    = 55'u8
  Tlink*       = 70'u8
  Rlink*       = 71'u8
  Tmkdir*      = 72'u8
  Rmkdir*      = 73'u8
  Trenameat*   = 74'u8
  Rrenameat*   = 75'u8
  Tunlinkat*   = 76'u8
  Runlinkat*   = 77'u8

  # Open/create modes
  Oread*   = 0'u8
  Owrite*  = 1'u8
  Ordwr*   = 2'u8
  Oexec*   = 3'u8
  Otrunc*  = 0x10'u8

  # Qid types
  QtDir*    = 0x80'u8
  QtAppend* = 0x40'u8
  QtExcl*   = 0x20'u8
  QtAuth*   = 0x08'u8
  QtTmp*    = 0x04'u8
  QtFile*   = 0x00'u8

  # Dir mode bits
  DmDir*    = 0x80000000'u32
  DmAppend* = 0x40000000'u32
  DmExcl*   = 0x20000000'u32
  DmTmp*    = 0x04000000'u32

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  Qid* = object
    ## 13-byte server-unique file identifier.
    qtype*: uint8    ## type (dir, file, etc.)
    version*: uint32 ## version number (changes on write)
    path*: uint64    ## unique path identifier

  Stat9* = object
    ## 9P2000 stat structure.
    stype*: uint16
    dev*: uint32
    qid*: Qid
    mode*: uint32
    atime*: uint32
    mtime*: uint32
    length*: uint64
    name*: string
    uid*: string
    gid*: string
    muid*: string

# =====================================================================================================================
# LE encode helpers
# =====================================================================================================================

proc encode_u8*(val: uint8): string =
  result = newString(1)
  result[0] = char(val)

proc encode_u16*(val: uint16): string =
  result = newString(2)
  result[0] = char(val and 0xFF)
  result[1] = char((val shr 8) and 0xFF)

proc encode_u32*(val: uint32): string =
  result = newString(4)
  result[0] = char(val and 0xFF)
  result[1] = char((val shr 8) and 0xFF)
  result[2] = char((val shr 16) and 0xFF)
  result[3] = char((val shr 24) and 0xFF)

proc encode_u64*(val: uint64): string =
  result = newString(8)
  for i in 0 ..< 8:
    result[i] = char((val shr (i * 8)) and 0xFF)

proc encode_str*(s: string): string =
  ## 2-byte LE length prefix + data.
  result = encode_u16(uint16(s.len)) & s

proc encode_data*(d: string): string =
  ## 4-byte LE length prefix + data (for read/write payloads).
  result = encode_u32(uint32(d.len)) & d

# =====================================================================================================================
# LE decode helpers
# =====================================================================================================================

proc decode_u8*(buf: string, pos: var int): uint8 {.raises: [NinepError].} =
  if pos + 1 > buf.len:
    raise newException(NinepError, "buffer too short for u8")
  result = uint8(buf[pos])
  inc pos

proc decode_u16*(buf: string, pos: var int): uint16 {.raises: [NinepError].} =
  if pos + 2 > buf.len:
    raise newException(NinepError, "buffer too short for u16")
  result = uint16(uint8(buf[pos])) or (uint16(uint8(buf[pos + 1])) shl 8)
  pos += 2

proc decode_u32*(buf: string, pos: var int): uint32 {.raises: [NinepError].} =
  if pos + 4 > buf.len:
    raise newException(NinepError, "buffer too short for u32")
  result = uint32(uint8(buf[pos])) or
           (uint32(uint8(buf[pos + 1])) shl 8) or
           (uint32(uint8(buf[pos + 2])) shl 16) or
           (uint32(uint8(buf[pos + 3])) shl 24)
  pos += 4

proc decode_u64*(buf: string, pos: var int): uint64 {.raises: [NinepError].} =
  if pos + 8 > buf.len:
    raise newException(NinepError, "buffer too short for u64")
  for i in 0 ..< 8:
    result = result or (uint64(uint8(buf[pos + i])) shl (i * 8))
  pos += 8

proc decode_str*(buf: string, pos: var int): string {.raises: [NinepError].} =
  let length = int(decode_u16(buf, pos))
  if pos + length > buf.len:
    raise newException(NinepError, "buffer too short for string")
  result = buf[pos ..< pos + length]
  pos += length

proc decode_data*(buf: string, pos: var int): string {.raises: [NinepError].} =
  let length = int(decode_u32(buf, pos))
  if pos + length > buf.len:
    raise newException(NinepError, "buffer too short for data")
  result = buf[pos ..< pos + length]
  pos += length

# =====================================================================================================================
# Qid encode/decode
# =====================================================================================================================

proc encode_qid*(q: Qid): string =
  result = encode_u8(q.qtype) & encode_u32(q.version) & encode_u64(q.path)

proc decode_qid*(buf: string, pos: var int): Qid {.raises: [NinepError].} =
  result.qtype = decode_u8(buf, pos)
  result.version = decode_u32(buf, pos)
  result.path = decode_u64(buf, pos)

# =====================================================================================================================
# Stat encode/decode
# =====================================================================================================================

proc encode_stat*(s: Stat9): string =
  ## Encode a stat structure. The result does NOT include the 2-byte size prefix
  ## that wraps stat in Tstat/Twstat messages.
  result = encode_u16(s.stype)
  result.add(encode_u32(s.dev))
  result.add(encode_qid(s.qid))
  result.add(encode_u32(s.mode))
  result.add(encode_u32(s.atime))
  result.add(encode_u32(s.mtime))
  result.add(encode_u64(s.length))
  result.add(encode_str(s.name))
  result.add(encode_str(s.uid))
  result.add(encode_str(s.gid))
  result.add(encode_str(s.muid))

proc decode_stat*(buf: string, pos: var int): Stat9 {.raises: [NinepError].} =
  result.stype = decode_u16(buf, pos)
  result.dev = decode_u32(buf, pos)
  result.qid = decode_qid(buf, pos)
  result.mode = decode_u32(buf, pos)
  result.atime = decode_u32(buf, pos)
  result.mtime = decode_u32(buf, pos)
  result.length = decode_u64(buf, pos)
  result.name = decode_str(buf, pos)
  result.uid = decode_str(buf, pos)
  result.gid = decode_str(buf, pos)
  result.muid = decode_str(buf, pos)
