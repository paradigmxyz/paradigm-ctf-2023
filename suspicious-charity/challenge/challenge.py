from typing import Dict

from ctf_launchers.pwn_launcher import PwnChallengeLauncher
from ctf_server.types import DaemonInstanceArgs, UserData


class Challenge(PwnChallengeLauncher):
    def get_daemon_instances(self) -> Dict[str, DaemonInstanceArgs]:
        return {
            "watcher": DaemonInstanceArgs(
                image="gcr.io/paradigm-ctf/suspicious-charity-watcher:latest"
            )
        }

    def is_solved(self, user_data: UserData, addr: str) -> bool:
        return (
            int(user_data["metadata"].get("donated", "0")) > 100000000000000000000000000
        )


Challenge().run()
