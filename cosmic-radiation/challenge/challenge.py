from typing import Dict

from ctf_launchers.koth_launcher import KothChallengeLauncher
from ctf_server.types import LaunchAnvilInstanceArgs, UserData, get_privileged_web3
from foundry.anvil import anvil_setBalance, anvil_setCode
from web3 import Web3


class Challenge(KothChallengeLauncher):
    def __init__(self):
        super().__init__(want_metadata=["bitflips"])

    def get_anvil_instances(self) -> Dict[str, LaunchAnvilInstanceArgs]:
        return {
            "main": self.get_anvil_instance(fork_block_num=18_437_825),
        }

    def deploy(self, user_data: UserData, mnemonic: str) -> str:
        web3 = get_privileged_web3(user_data, "main")

        corrupted_addrs = {}

        bitflips = []

        while True:
            bitflip = input("bitflip? ")
            if bitflip == "":
                break

            bitflips.append(bitflip)

            (addr, *bits) = bitflip.split(":")
            addr = Web3.to_checksum_address(addr)
            bits = [int(v) for v in bits]

            print(f"corrupting {addr} {bits}")

            if addr in corrupted_addrs:
                raise Exception("already corrupted this address")

            corrupted_addrs[addr] = True

            balance = web3.eth.get_balance(addr)
            if balance == 0:
                raise Exception("invalid target")

            code = bytearray(web3.eth.get_code(addr))
            for bit in bits:
                byte_offset = bit // 8
                bit_offset = 7 - bit % 8
                if byte_offset < len(code):
                    code[byte_offset] ^= 1 << bit_offset

            total_bits = len(code) * 8
            corrupted_balance = int(balance * (total_bits - len(bits)) / total_bits)

            anvil_setBalance(web3, addr, hex(corrupted_balance))
            anvil_setCode(web3, addr, "0x" + code.hex())

        self.update_metadata({"bitflips": ",".join(bitflips)})

        return super().deploy(user_data, mnemonic)


Challenge().run()
