import asyncio
import sys
import time
import traceback
import typing

from ctf_launchers.daemon import Daemon
from ctf_server.types import UserData, get_unprivileged_web3
import requests


class Watcher(Daemon):
    def __init__(self) -> None:
        super().__init__(required_properties=["challenge_address", "mnemonic"])
        self.__router_address = ""
        self.__price_cache = {}
        self.__pair_cache = {}

    async def _init(self, user_data: UserData):
        self.__rpc_url = get_unprivileged_web3(user_data, "main").provider.endpoint_uri
        self.__challenge_contract = user_data["metadata"]["challenge_address"]
        self.__router_address = (
            await self.call(
                await self.get_block_number(),
                self.__challenge_contract,
                "ROUTER()(address)",
            )
        ).strip()
        print("router address = ", self.__router_address)

    def _run(self, user_data: UserData):
        asyncio.run(self.async_run(user_data))

    async def async_run(self, user_data: UserData):
        await self._init(user_data)

        while True:
            try:
                block_number = await self.get_block_number()

                flag_charity = await self.call(
                    block_number,
                    self.__router_address,
                    "flagCharity()(address)",
                )

                listing_tokens = await self.list_array(
                    block_number,
                    self.__router_address,
                    "listingTokensCount()(uint256)",
                    "listingTokens(uint256)(address)",
                )
                lp_tokens = await self.list_array(
                    block_number,
                    self.__router_address,
                    "lpTokensCount()(uint256)",
                    "lpTokensInfo(uint256)(string,address)",
                )
                lp_tokens = [info.rsplit("\n", 1) for info in lp_tokens]

                async def calculate_token_price(addr):
                    price = await self.get_token_price(block_number, addr)
                    amount = await self.get_balance(block_number, addr, flag_charity)
                    return price * amount

                async def calculate_lp_token_price(i, res):
                    pool, addr = res
                    amount = await self.get_balance(block_number, addr, flag_charity)
                    (
                        token_amount_a,
                        token_amount_b,
                        total_supply,
                    ) = await self.get_pair_status(block_number, addr)

                    if total_supply == 0:
                        return 0

                    (price_a, price_b) = await self.get_pair_prices(
                        block_number, i, pool
                    )
                    return (
                        ((price_a * token_amount_a) + (price_b * token_amount_b))
                        * amount
                        // total_supply
                    )

                acc = 0

                # Normal tokens
                acc += sum(
                    await asyncio.gather(
                        *[calculate_token_price(addr) for addr in listing_tokens]
                    )
                )

                # LP tokens
                acc += sum(
                    await asyncio.gather(
                        *[
                            calculate_lp_token_price(i, res)
                            for i, res in enumerate(lp_tokens)
                        ]
                    )
                )

                print("user has donated", acc // 10**18)

                self.update_metadata(
                    {
                        "donated": str(acc),
                    }
                )
            except:
                traceback.print_exc()
                pass
            finally:
                await asyncio.sleep(1)

    async def get_token_price(self, block_number, addr: str) -> int:
        key = "token_%s" % addr
        if key not in self.__price_cache:
            self.__price_cache[key] = int(
                (
                    await self.call(
                        block_number,
                        self.__router_address,
                        "priceOf(address)(uint256)",
                        addr,
                    )
                ).split(" ")[0]
            )

        return self.__price_cache[key]

    async def get_pair_prices(
        self, block_number: int, index: str, pool_id: str
    ) -> typing.Tuple[int, int]:
        pool_name = "pool_%s" % pool_id
        if pool_name not in self.__pair_cache:
            token_a, token_b = (
                await self.call(
                    block_number,
                    self.__router_address,
                    "lpTokenPair(uint256)(address,address)",
                    str(index),
                )
            ).split()
            self.__pair_cache[pool_name] = (token_a, token_b)

        token_a, token_b = self.__pair_cache[pool_name]

        return (
            await self.get_token_price(block_number, token_a),
            await self.get_token_price(block_number, token_b),
        )

    async def get_pair_status(
        self, block_number: int, pair: str
    ) -> typing.Tuple[int, int, int]:
        result = await self.call(
            block_number,
            self.__router_address,
            "lpTokensStatus(address)(uint256,uint256,uint256)",
            pair,
        )
        return [int(x.split(" ")[0], 0) for x in result.strip().split("\n")]

    async def get_balance(self, block_number: int, token: str, who: str) -> int:
        result = await self.call(block_number, token, "balanceOf(address)", who)
        return int(result.strip(), 0)

    async def list_array(
        self, block_number, address, count_sig, element_sig
    ) -> typing.List[str]:
        res = await self.call(
            block_number,
            address,
            count_sig,
        )
        count = int(res)

        result = await asyncio.gather(
            *[
                self.call(
                    block_number,
                    address,
                    element_sig,
                    str(i),
                )
                for i in range(count)
            ]
        )
        return result

    async def call(self, block_number: int, address: str, sig: str, *call_args) -> str:
        proc = await asyncio.create_subprocess_exec(
            "/opt/foundry/bin/cast",
            "call",
            "--rpc-url",
            self.__rpc_url,
            "-b",
            str(block_number),
            address,
            sig,
            *call_args,
            stdout=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()
        return stdout.decode()[:-1]

    async def get_block_number(self) -> int:
        proc = await asyncio.create_subprocess_exec(
            "/opt/foundry/bin/cast",
            "block-number",
            "--rpc-url",
            self.__rpc_url,
            stdout=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()
        return int(stdout)


Watcher().start()
