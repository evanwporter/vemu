import struct
import json
import sys


def read_u32(buf, offset):
    if offset + 4 > len(buf):
        raise RuntimeError("buffer overrun")
    val = struct.unpack_from("<I", buf, offset)[0]
    return val, offset + 4


def decode_state(buf, offset):
    _, offset = read_u32(buf, offset)
    _, offset = read_u32(buf, offset)

    v = []
    for _ in range(40):
        val, offset = read_u32(buf, offset)
        v.append(val)

    state = {
        "R": v[0:16],
        "R_fiq": v[16:23],
        "R_svc": v[23:25],
        "R_abt": v[25:27],
        "R_irq": v[27:29],
        "R_und": v[29:31],
        "CPSR": v[31],
        "SPSR": v[32:37],
        "pipeline": v[37:39],
        "access": v[39],
    }

    return state, offset


def decode_transactions(buf, offset):
    _, offset = read_u32(buf, offset)

    mn, offset = read_u32(buf, offset)
    if mn != 3:
        raise RuntimeError("transactions: bad mn")

    count, offset = read_u32(buf, offset)

    txs = []
    for _ in range(count):
        kind, offset = read_u32(buf, offset)
        size, offset = read_u32(buf, offset)
        addr, offset = read_u32(buf, offset)
        data, offset = read_u32(buf, offset)
        cycle, offset = read_u32(buf, offset)
        access, offset = read_u32(buf, offset)

        txs.append(
            {
                "kind": kind,
                "size": size,
                "addr": addr,
                "data": data,
                "cycle": cycle,
                "access": access,
            }
        )

    return txs, offset


def decode_test(buf):
    offset = 0

    _, offset = read_u32(buf, offset)

    initial, offset = decode_state(buf, offset)
    final, offset = decode_state(buf, offset)
    transactions, offset = decode_transactions(buf, offset)

    _, offset = read_u32(buf, offset)
    _, offset = read_u32(buf, offset)

    opcode, offset = read_u32(buf, offset)
    base_addr, offset = read_u32(buf, offset)

    return {
        "initial": initial,
        "final": final,
        "transactions": transactions,
        "opcode": opcode,
        "base_addr": base_addr,
    }


class TestStream:
    def __init__(self, path):
        self.f = open(path, "rb")

        magic = struct.unpack("<I", self.f.read(4))[0]
        self.num_tests = struct.unpack("<I", self.f.read(4))[0]

        if magic != 0xD33DBAE0:
            raise RuntimeError("Bad test file")

        self.tests_left = self.num_tests

    def next(self):
        if self.tests_left <= 0:
            return None

        self.tests_left -= 1

        sz_bytes = self.f.read(4)
        if not sz_bytes:
            return None

        sz = struct.unpack("<i", sz_bytes)[0]
        if sz < 4:
            raise RuntimeError("Unexpected EOF")

        buf = bytearray(sz)
        buf[0:4] = sz_bytes
        rest = self.f.read(sz - 4)
        if len(rest) != sz - 4:
            raise RuntimeError("Unexpected EOF")

        buf[4:] = rest

        return decode_test(buf)


path = "tests\\GameboyAdvanceCPUTests\\v1\\arm_b_bl.json.bin"
target_index = 20000

ts = TestStream(path)

for i in range(ts.num_tests):
    test = ts.next()
    if test is None:
        break

    if i == target_index:
        print(json.dumps(test, indent=2))
        break
else:
    print(f"Test index {target_index} out of range (max {ts.num_tests - 1})")
