// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract DiceBattleGame is Ownable, VRFConsumerBase {
    //Chainlink variables
    uint256 public vrfFee;
    bytes32 public vrfKeyHash;

    address[] public players;
    uint8 maxPlayers;
    bool public gameOpened;
    uint256 entryFee;
    uint256 currentGameId;

    event GameOpened(uint256 gameId, uint8 maxPlayers, uint256 entryFee);
    event PlayerJoined(uint256 gameId, address player);
    event GameEnded(uint256 gameId, address winner, bytes32 requestId);

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _vrfKeyHash,
        uint256 _vrfFee
    ) VRFConsumerBase(vrfCoordinator, linkToken) {
        vrfKeyHash = _vrfKeyHash;
        vrfFee = _vrfFee;
        gameOpened = false;
    }

    function openGame(uint8 _maxPlayers, uint256 _entryFee) public onlyOwner {
        require(!gameOpened, "Game is already started");
        require(_maxPlayers > 0, "Max players has to be > 0");
        delete players;
        maxPlayers = _maxPlayers;
        gameOpened = true;
        entryFee = _entryFee;
        currentGameId += 1;
        emit GameOpened(currentGameId, maxPlayers, entryFee);
    }

    // called when a player wants to enter the game.
    function joinGame() public payable {
        require(gameOpened, "Game has to be opened before joining");
        require(msg.value == entryFee, "Value not equal to game entry fee");
        require(players.length < maxPlayers, "Game is full");
        players.push(msg.sender);
        emit PlayerJoined(currentGameId, msg.sender);
    }

    function resolveGame() public {
        require(players.length == maxPlayers, "Game not full");
        getRandomNumber();
    }

    function getRandomNumber() public returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(
        bytes32 requestId,
        uint256 randomness
    ) internal override {
        uint256[] randomNumberArray = getRandomNumberArray(randomness);
        address winner = getWinner(randomNumberArray);
        (bool sent,) = winner.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
        emit GameEnded(gameId, winner,requestId);
        gameOpened = false;
    }

    function getWinner(uint256[] memory randomNumberArray) returns (uint8 winnerIndex) {
        uint256 largest = 0; 
        uint256 i;
        for(i = 0; i < randomNumberArray.length; i++){
            if(randomNumberArray[i] > largest) {
                largest = numbers[i];
                winnerIndex = i;
            } 
        }
        return players[winnerIndex];
    }

    function getRandomNumberArray(
        uint256 randomness
    ) returns (uint256[] memory randomNumberArray) {
        randomNumberArray = new uint256[](maxPlayers);
        for (uint256 i = 0; i < maxPlayers; i++) {
            randomNumberArray[i] =
                uint256(keccak256(abi.encode(randomness, i))) %
                100;
        }
        return randomNumberArray;
    }
}
