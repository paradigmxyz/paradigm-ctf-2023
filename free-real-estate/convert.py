import json

with open("CTF_airdrop_allocations.csv", "r") as f:
    data = f.read().split("\n")[1:]


obj = {}

tot = 0
for line in data:
    if line == "":
        continue
    addr, amnt = line.split(",")
    obj[addr] = int(amnt) * int(10**18)
    tot += int(amnt)


print(tot)

with open("allocations.json", "w") as f:
    json.dump(obj, f)
