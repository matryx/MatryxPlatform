pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "../MatryxPlatform.sol";
import "../LibTournament.sol";

interface ITournament2 {
    function getInfo() external pure returns (LibTournament.TournamentInfo memory);
    function getRounds() external view returns (LibTournament.RoundDetails memory);
    function getBalance() external pure returns (uint256);
    function createRound() external returns (uint256);
}

library LibTournament2 {

    function getInfo(address self, address, MatryxPlatform.Data storage data) public view returns (LibTournament.TournamentInfo memory) {
        return data.tournaments[self].info;
    }

    function getRounds(address self, address, MatryxPlatform.Data storage data) public view returns (LibTournament.RoundDetails memory) {
        return data.tournaments[self].rounds[0].details;
    }

    function getBalance(address self, address, MatryxPlatform.Data storage) public pure returns (uint256) {
        return 99000000000000000000;
    }

    function createRound(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public returns (uint256) {
        LibTournament.RoundData memory round;
        round.details.start = 12345;
        round.details.duration = 12345;
        round.details.review = 12345;
        round.details.bounty = 12345;
        data.tournaments[self].rounds.push(round);
        return 0;
    }

}
