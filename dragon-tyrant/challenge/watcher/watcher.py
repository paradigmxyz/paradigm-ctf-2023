import random
import time
from typing import Dict

from ctf_launchers.daemon import Daemon
from ctf_server.types import UserData, get_additional_account, get_unprivileged_web3
from eth_abi import abi
from web3.middleware.signing import construct_sign_and_send_raw_middleware


class Watcher(Daemon):
    def __init__(self):
        super().__init__(required_properties=["mnemonic", "challenge_address"])

    def _run(self, user_data: UserData):
        randomness_provider = get_additional_account(
            user_data["metadata"]["mnemonic"], 0
        )

        web3 = get_unprivileged_web3(user_data, "main")
        web3.middleware_onion.add(
            construct_sign_and_send_raw_middleware(randomness_provider)
        )
        (nft,) = abi.decode(
            ["address"],
            web3.eth.call(
                {
                    "to": user_data["metadata"]["challenge_address"],
                    "data": web3.keccak(text="TOKEN()")[:4].hex(),
                }
            ),
        )

        from_number = web3.eth.block_number - 1

        while True:
            latest_number = web3.eth.block_number

            print(f"from_number={from_number} latest={latest_number}")

            if from_number > latest_number:
                time.sleep(1)
                continue

            logs = web3.eth.get_logs(
                {
                    "address": web3.to_checksum_address(nft),
                    "topics": [
                        web3.keccak(text="RequestOffchainRandomness()").hex(),
                    ],
                    "fromBlock": from_number,
                    "toBlock": latest_number,
                }
            )

            for log in logs:
                print(f"fetched log={web3.to_json(log)}")
                txhash = web3.eth.send_transaction(
                    {
                        "from": randomness_provider.address,
                        "to": web3.to_checksum_address(nft),
                        "data": (
                            web3.keccak(text="resolveRandomness(bytes32)")[:4]
                            + random.randbytes(32)
                        ).hex(),
                        "gas": 1_000_000,
                        "gasPrice": int(40e9),
                    }
                )

                print(f"resolved randomness txhash={txhash.hex()}")

            from_number = latest_number + 1


Watcher().start()
