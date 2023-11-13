import time

from ctf_solvers.pwn_solver import PwnChallengeSolver
from ctf_solvers.utils import solve
from web3 import Web3


class Solver(PwnChallengeSolver):
    def _solve(self, rpcs, player, challenge):
        web3 = Web3(Web3.HTTPProvider(rpcs[0]))
        solve(web3, "project", player, challenge, "script/Solve.s.sol:Solve1")
        time.sleep(2)
        solve(web3, "project", player, challenge, "script/Solve.s.sol:Solve2")


Solver().start()
