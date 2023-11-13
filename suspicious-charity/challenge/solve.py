import time

from ctf_solvers.pwn_solver import PwnChallengeSolver


class Solver(PwnChallengeSolver):
    def _solve(self, rpcs, player, challenge):
        super()._solve(rpcs, player, challenge)

        # wait for watcher to pick it up
        time.sleep(5)


Solver().start()
