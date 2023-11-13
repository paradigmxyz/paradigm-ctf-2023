from Crypto.Util.number import *
from pwn import *
from math import ceil
from tqdm import tqdm

io = remote("127.0.0.1", "1337")

NUMS = 5

def custom_hash(n):
    state = b"\x00"*16
    for i in range(len(n)//16):
        state = xor(state, n[i:i+16])

    for _ in range(5):
        state = hashlib.md5(state).digest()
        state = hashlib.sha1(state).digest()
        state = hashlib.sha256(state).digest()
        state = hashlib.sha512(state).digest() + hashlib.sha256(state).digest()

    value = bytes_to_long(state)

    return value

def get_plaintext():
    io.recvuntil(b"Choice: ")
    io.sendline(b"1")
    io.recvline()
    t = int(io.recvline().split()[-1].strip())
    r = int(io.recvline().split()[-1].strip())
    io.recvline()
    p = int(io.recvline().split()[-1].strip())
    g = int(io.recvline().split()[-1].strip())
    y = int(io.recvline().split()[-1].strip())

    return (t,r), (p,g,y)

ts, rs = [], []
ps, gs, ys = [], [], []

for i in tqdm(range(NUMS)):
    (t,r), (p,g,y) = get_plaintext()

    ts.append(t)
    rs.append(r)
    ps.append(p)
    gs.append(g)
    ys.append(y)

io.close()

M = Matrix(ZZ, NUMS + 2, NUMS + 2)
BOUND = 2^384

for i,j in zip(range(NUMS), ps):
    M[i,i] = j-1

M[-1,-1] = BOUND
M[-2,-2] = 1

for i in range(len(rs)):
    M[-1, i] = rs[i] - 1

for a,b,c,i in zip(gs,ys,ts,range(len(rs))):
    c = custom_hash(long_to_bytes(a) + long_to_bytes(b) + long_to_bytes(c))
    M[-2, i] = c

ans = M.LLL()
flag = int(ans[0,-2])
print("pctf{" + long_to_bytes(flag).decode('utf8') + "}")
