from typing import Dict

from ctf_launchers.pwn_launcher import PwnChallengeLauncher
from ctf_server.types import DaemonInstanceArgs, LaunchAnvilInstanceArgs


class Challenge(PwnChallengeLauncher):
    def get_anvil_instances(self) -> Dict[str, LaunchAnvilInstanceArgs]:
        return {"main": self.get_anvil_instance(accounts=3)}

    def get_daemon_instances(self) -> Dict[str, DaemonInstanceArgs]:
        return {
            "watcher": DaemonInstanceArgs(
                image="gcr.io/paradigm-ctf/dragon-tyrant-watcher:latest"
            ),
        }


Challenge().run()
