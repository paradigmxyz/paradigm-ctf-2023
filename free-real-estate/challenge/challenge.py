import json
from typing import Dict

from ctf_launchers.koth_launcher import KothChallengeLauncher
from ctf_server.types import DaemonInstanceArgs, UserData


class Challenge(KothChallengeLauncher):
    def __init__(self):
        super().__init__(want_metadata=["claimed"])

    def get_daemon_instances(self) -> Dict[str, DaemonInstanceArgs]:
        return {
            "watcher": DaemonInstanceArgs(
                image="gcr.io/paradigm-ctf/free-real-estate-watcher:latest"
            )
        }

    def get_deployment_args(self, user_data: UserData) -> Dict[str, str]:
        with open("challenge/airdrop-merkle-proofs.json", "r") as f:
            airdrop_data = json.load(f)

        return {
            "MERKLE_ROOT": airdrop_data["merkleRoot"],
            "TOKEN_TOTAL": airdrop_data["tokenTotal"],
        }


Challenge().run()
