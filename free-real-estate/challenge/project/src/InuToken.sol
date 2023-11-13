// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InuToken is ERC20 {
    constructor(uint256 mintAmount) ERC20("Inu Token", "INU") {
        _mint(msg.sender, mintAmount);
    }
}
