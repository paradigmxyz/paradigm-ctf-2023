import json
from typing import Dict

from ctf_launchers.launcher import ETH_RPC_URL
from ctf_launchers.pwn_launcher import PwnChallengeLauncher
from ctf_launchers.team_provider import get_team_provider
from ctf_launchers.utils import anvil_setCodeFromFile, deploy
from ctf_server.types import (
    DaemonInstanceArgs,
    LaunchAnvilInstanceArgs,
    UserData,
    get_additional_account,
    get_privileged_web3,
)
from eth_abi import abi
from foundry.anvil import anvil_autoImpersonateAccount, anvil_setStorageAt


class Challenge(PwnChallengeLauncher):
    def get_anvil_instances(self) -> Dict[str, LaunchAnvilInstanceArgs]:
        return {
            "l1": self.get_anvil_instance(chain_id=78704, accounts=3, fork_url=None),
            "l2": self.get_anvil_instance(
                image="gcr.io/paradigm-ctf/enterprise-blockchain-anvil:latest",
                chain_id=78705,
                accounts=3,
                fork_url=None,
            ),
        }

    def get_daemon_instances(self) -> Dict[str, DaemonInstanceArgs]:
        return {
            "relayer": DaemonInstanceArgs(
                image="gcr.io/paradigm-ctf/enterprise-blockchain-relayer:latest"
            )
        }

    def deploy(self, user_data: UserData, mnemonic: str) -> str:
        l1_web3 = get_privileged_web3(user_data, "l1")
        l2_web3 = get_privileged_web3(user_data, "l2")

        anvil_autoImpersonateAccount(l2_web3, True)
        challenge = deploy(
            l1_web3,
            self.project_location,
            mnemonic=mnemonic,
            env={
                "L1_RPC": l1_web3.provider.endpoint_uri,
                "L2_RPC": l2_web3.provider.endpoint_uri,
            },
        )
        anvil_autoImpersonateAccount(l2_web3, False)

        # deploy multisig
        anvil_setCodeFromFile(
            l2_web3,
            "0x0000000000000000000000000000000000031337",
            "MultiSig.sol:SimpleMultiSigGov",
        )
        for i in range(3):
            owner_addr = get_additional_account(mnemonic, 1 + i)
            anvil_setStorageAt(
                l2_web3,
                "0x0000000000000000000000000000000000031337",
                hex(i),
                "0x" + owner_addr.address[2:].ljust(64, "0"),
            )

        with open("/artifacts/out/Bridge.sol/Bridge.json", "r") as f:
            cache = json.load(f)

            bridge_abi = cache["metadata"]["output"]["abi"]

        self.update_metadata(
            {
                "bridge_abi": json.dumps(bridge_abi),
            }
        )

        return challenge

    def is_solved(self, user_data: UserData, addr: str) -> bool:
        web3 = get_privileged_web3(user_data, "l1")

        (result,) = abi.decode(
            ["bool"],
            web3.eth.call(
                {
                    "to": addr,
                    "data": web3.keccak(text="isSolved()")[:4],
                }
            ),
        )
        return result


Challenge().run()
