from ctf_launchers.pwn_launcher import PwnChallengeLauncher
from ctf_launchers.utils import anvil_setCodeFromFile
from ctf_server.types import UserData, get_privileged_web3


class Challenge(PwnChallengeLauncher):
    def deploy(self, user_data: UserData, mnemonic: str) -> str:
        anvil_setCodeFromFile(
            get_privileged_web3(user_data, "main"),
            "0x7f5C649856F900d15C83741f45AE46f5C6858234",
            "UNCX_ProofOfReservesV2_UniV3.sol:UNCX_ProofOfReservesV2_UniV3",
        )

        return super().deploy(user_data, mnemonic)


Challenge().run()
