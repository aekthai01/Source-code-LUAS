#!/usr/bin/env python3
import argparse
import hashlib
import struct
from pathlib import Path

LUA_SIGNATURE = b"\x1bLua"
LUA53_VERSION = 0x53

STANDARD_NAMES = [
    "MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE",
    "SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW",
    "DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT",
    "JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP",
    "FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG",
]

RAW_TO_NAME = {
    0:"MOVE", 1:"SELF", 2:"ADD", 3:"SUB", 4:"MUL", 5:"MOD", 6:"POW", 7:"DIV",
    8:"IDIV", 9:"BAND", 10:"BOR", 11:"BXOR", 12:"SHL", 13:"SHR", 14:"UNM",
    15:"BNOT", 16:"NOT", 17:"LEN", 18:"CONCAT", 19:"JMP", 20:"EQ", 21:"LT",
    22:"LE", 23:"TEST", 24:"TESTSET", 25:"CALL", 26:"TAILCALL", 27:"RETURN",
    28:"FORLOOP", 29:"FORPREP", 30:"TFORCALL", 31:"TFORLOOP", 32:"SETLIST",
    33:"CLOSURE", 34:"VARARG", 35:"LOADK", 36:"LOADKX", 37:"LOADBOOL",
    38:"LOADNIL", 39:"GETUPVAL", 40:"GETTABUP", 41:"GETTABLE", 42:"SETTABUP",
    43:"SETUPVAL", 44:"SETTABLE", 45:"NEWTABLE", 46:"EXTRAARG",
}
NAME_TO_STANDARD = {name: i for i, name in enumerate(STANDARD_NAMES)}
RAW_TO_STANDARD = {raw: NAME_TO_STANDARD[name] for raw, name in RAW_TO_NAME.items()}
STANDARD_TO_RAW = {std: raw for raw, std in RAW_TO_STANDARD.items()}

class ChunkError(RuntimeError):
    pass

class Scanner:
    def __init__(self, data: bytes):
        self.data = data
        self.o = 0
        self.endian = "<"
        self.cint_size = None
        self.sizet_size = None
        self.inst_size = None
        self.integer_size = None
        self.number_size = None
        self.instruction_offsets = []
        self.long_string_count = 0
        self.proto_count = 0

    def need(self, n):
        if self.o + n > len(self.data):
            raise ChunkError(f"truncated at 0x{self.o:x}, need {n} bytes")

    def take(self, n):
        self.need(n)
        b = self.data[self.o:self.o+n]
        self.o += n
        return b

    def u8(self):
        return self.take(1)[0]

    def uint(self, n):
        return int.from_bytes(self.take(n), "little", signed=False)

    def cint(self):
        return self.uint(self.cint_size)

    def string(self):
        first = self.u8()
        if first == 0:
            return None
        if first == 0xff:
            self.long_string_count += 1
            size = self.uint(self.sizet_size)
        else:
            size = first
        if size == 0:
            return b""
        return self.take(size - 1)

    def header(self):
        if self.take(4) != LUA_SIGNATURE:
            raise ChunkError("not a Lua chunk")
        version = self.u8()
        fmt = self.u8()
        if version != LUA53_VERSION or fmt != 0:
            raise ChunkError(f"expected Lua 5.3 format 0, got version=0x{version:02x} format={fmt}")
        if self.take(6) != b"\x19\x93\r\n\x1a\n":
            raise ChunkError("LUAC_DATA mismatch")

        self.cint_size = self.u8()
        self.sizet_size = self.u8()
        self.inst_size = self.u8()
        self.integer_size = self.u8()
        self.number_size = self.u8()
        if self.inst_size != 4:
            raise ChunkError(f"unsupported instruction size {self.inst_size}")
        self.take(self.integer_size)  # LUAC_INT
        self.take(self.number_size)   # LUAC_NUM
        main_nup = self.u8()
        return {
            "version": version,
            "format": fmt,
            "cint_size": self.cint_size,
            "sizet_size": self.sizet_size,
            "instruction_size": self.inst_size,
            "integer_size": self.integer_size,
            "number_size": self.number_size,
            "main_nup": main_nup,
        }

    def proto(self):
        self.proto_count += 1
        self.string()
        self.take(self.cint_size * 2)  # linedefined + lastlinedefined
        self.take(3)                   # numparams, is_vararg, maxstack

        ncode = self.cint()
        for _ in range(ncode):
            self.instruction_offsets.append(self.o)
            self.take(self.inst_size)

        nconst = self.cint()
        for _ in range(nconst):
            tag = self.u8()
            if tag == 0:          # nil
                pass
            elif tag == 1:        # boolean
                self.take(1)
            elif tag == 3:        # float
                self.take(self.number_size)
            elif tag == 19:       # integer
                self.take(self.integer_size)
            elif tag in (4, 20):  # short/long string tags
                self.string()
            else:
                raise ChunkError(f"unknown constant tag {tag} at 0x{self.o-1:x}")

        nup = self.cint()
        self.take(nup * 2)

        nproto = self.cint()
        for _ in range(nproto):
            self.proto()

        nline = self.cint()
        self.take(nline * self.cint_size)

        nloc = self.cint()
        for _ in range(nloc):
            self.string()
            self.take(self.cint_size * 2)

        nupnames = self.cint()
        for _ in range(nupnames):
            self.string()

    def scan(self):
        hdr = self.header()
        self.proto()
        if self.o != len(self.data):
            raise ChunkError(f"trailing bytes: stopped 0x{self.o:x}, size 0x{len(self.data):x}")
        return hdr

def transform(data: bytes, direction: str, target_size_t=None) -> bytes:
    scanner = Scanner(data)
    hdr = scanner.scan()
    out = bytearray(data)

    if target_size_t is not None and target_size_t != hdr["sizet_size"]:
        if scanner.long_string_count:
            raise ChunkError(
                "cannot change size_t width by header patch because the chunk contains "
                f"{scanner.long_string_count} long-string length field(s)"
            )
        if target_size_t not in (4, 8):
            raise ChunkError("target size_t must be 4 or 8")
        out[13] = target_size_t

    if direction == "to-custom":
        table = STANDARD_TO_RAW
    elif direction == "to-standard":
        table = RAW_TO_STANDARD
    else:
        raise ChunkError("direction must be to-custom or to-standard")

    for off in scanner.instruction_offsets:
        word = struct.unpack_from("<I", out, off)[0]
        opcode = word & 0x3f
        if opcode not in table:
            raise ChunkError(f"opcode {opcode} at 0x{off:x} has no mapping")
        new_word = (word & ~0x3f) | table[opcode]
        struct.pack_into("<I", out, off, new_word)

    return bytes(out)

def sha256(data):
    return hashlib.sha256(data).hexdigest()

def main():
    ap = argparse.ArgumentParser(description="Remap SPECTRA Lua 5.3 opcode permutation")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--to-custom", action="store_true")
    mode.add_argument("--to-standard", action="store_true")
    ap.add_argument("--target-size-t", type=int, choices=(4,8))
    ap.add_argument("input")
    ap.add_argument("output")
    args = ap.parse_args()

    src = Path(args.input).read_bytes()
    direction = "to-custom" if args.to_custom else "to-standard"
    dst = transform(src, direction, args.target_size_t)
    Path(args.output).write_bytes(dst)

    s = Scanner(dst)
    hdr = s.scan()
    print(f"{args.output}: {len(dst)} bytes sha256={sha256(dst)}")
    print(
        f"Lua 5.3 size_t={hdr['sizet_size']} protos={s.proto_count} "
        f"instructions={len(s.instruction_offsets)} long_strings={s.long_string_count}"
    )

if __name__ == "__main__":
    main()
