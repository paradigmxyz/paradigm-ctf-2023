import json
import time
from typing import List

import requests
from ctf_launchers.daemon import ORCHESTRATOR, Daemon
from ctf_server.types import UserData, get_additional_account, get_unprivileged_web3
from eth_abi import abi
from web3 import Web3
from web3.middleware.signing import construct_sign_and_send_raw_middleware


class Watcher(Daemon):
    def __init__(self):
        super().__init__(required_properties=["challenge_address", "mnemonic"])

        self.__claimed = []

    def update_claimed(self, instance_id: str, claimed: List[str]):
        self.__claimed += claimed

        self.update_metadata(
            {
                "claimed": json.dumps(self.__claimed),
            }
        )

    def _run(self, user_data: UserData):
        randomness_provider = get_additional_account(
            user_data["metadata"]["mnemonic"], 0
        )

        web3 = get_unprivileged_web3(user_data, "main")
        web3.middleware_onion.add(
            construct_sign_and_send_raw_middleware(randomness_provider)
        )

        (distributor,) = abi.decode(
            ["address"],
            web3.eth.call(
                {
                    "to": user_data["metadata"]["challenge_address"],
                    "data": web3.keccak(text="MERKLE_DISTRIBUTOR()")[:4].hex(),
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
                    "address": web3.to_checksum_address(distributor),
                    "topics": [
                        web3.keccak(text="Claimed(uint256,address,uint256)").hex(),
                    ],
                    "fromBlock": from_number,
                    "toBlock": latest_number,
                }
            )

            claimed = []
            for log in logs:
                print(f"fetched log={web3.to_json(log)}")

                claimed.append(Web3.to_checksum_address(log["data"][44:64].hex()))

            if len(claimed) > 0:
                try:
                    self.update_claimed(user_data["instance_id"], claimed)
                except Exception as e:
                    print("failed to update claimed", e)

            from_number = latest_number + 1


Watcher().start()
