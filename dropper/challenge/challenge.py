import requests
from ctf_launchers.koth_launcher import KothChallengeLauncher
from ctf_launchers.launcher import ORCHESTRATOR_HOST
from ctf_server.types import get_privileged_web3
from eth_abi import abi
from web3 import Web3


class Challenge(KothChallengeLauncher):
    def __init__(self):
        super().__init__(want_metadata=["code"])

    def submit_score(self) -> int:
        instance_body = requests.get(
            f"{ORCHESTRATOR_HOST}/instances/{self.get_instance_id()}"
        ).json()
        if not instance_body["ok"]:
            print(instance_body["message"])
            return 1

        user_data = instance_body["data"]

        challenge_addr = user_data["metadata"]["challenge_address"]

        web3 = get_privileged_web3(instance_body["data"], "main")

        (code,) = abi.decode(
            ["bytes"],
            web3.eth.call(
                {
                    "to": Web3.to_checksum_address(challenge_addr),
                    "data": Web3.keccak(text="bestImplementation()")[:4].hex(),
                }
            ),
        )

        self.update_metadata(
            {
                "code": code.hex(),
            }
        )

        return super().submit_score()


Challenge().run()
