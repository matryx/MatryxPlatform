pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

import "./MatryxPlatform.sol";

import "./MatryxTrinity.sol";

import "./LibGlobals.sol";

contract MatryxRound is MatryxTrinity {
    constructor (uint256 _version, address _system) MatryxTrinity(_version, _system) public {}
}

interface IMatryxRound {
    function transferFrom(address, address, uint256) external;
    function transferTo(address, address, uint256) external;

    function getTournament() external view returns (address);
    function getStart() external view returns (uint256);
    function getEnd() external view returns (uint256);
    function getReview() external view returns (uint256);
    function getBounty() external view returns (uint256);
    function getBalance() external view returns (uint256);
    function getSubmissions() external view returns (address[]);
    function getData() external view returns (LibRound.RoundData);

    function getState() external view returns (uint256);
}

library LibRound {
    using SafeMath for uint256;

    // All information needed for creation of Round
    struct RoundDetails {
        uint256 start;
        uint256 end;
        uint256 review;
        uint256 bounty;
    }

    // All state data and details of Round
    struct RoundData {
        address tournament;
        RoundDetails details;
        address[] submissions;
        address[] winners;
        bool closed;
    }

    // All information needed to choose winning submissions
    struct WinnersData {
        address[] winners;
        uint256[] distribution;
        uint256 action;
    }

    /// @dev Returns the Tournament address of this Round
    function getTournament(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.rounds[self].tournament;
    }

    /// @dev Returns the start time of this Round (unix epoch time in seconds)
    function getStart(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].details.start;
    }

    /// @dev Returns the end time of this Round (unix epoch time in seconds)
    function getEnd(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].details.end;
    }

    /// @dev Returns the duration of the review period of this Round
    function getReview(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].details.review;
    }

    /// @dev Returns the bounty of this Round
    function getBounty(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].details.bounty;
    }

    function getBalance(address self, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public view returns (uint256) {
        return IMatryxToken(info.token).balanceOf(self);
    }

    /// @dev Returns all Submissions of this Round
    function getSubmissions(address self, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.rounds[self].submissions;
    }

    /// @dev Returns the data struct of this Round
    function getData(address self, address, MatryxPlatform.Data storage data) public view returns (LibRound.RoundData) {
        return data.rounds[self];
    }

    /// @dev Returns the state of this Round
    function getState(address self, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public returns (uint256) {
        LibRound.RoundData storage round = data.rounds[self];

        if (now < round.details.start) {
            return uint256(LibGlobals.RoundState.NotYetOpen);
        }
        else if (now < round.details.end) {
            if (IMatryxToken(info.token).balanceOf(self) == 0) {
                return uint256(LibGlobals.RoundState.Unfunded);
            }
            return uint256(LibGlobals.RoundState.Open);
        }
        else if (now < round.details.end.add(round.details.review)) {
            if (round.closed) {
                return uint256(LibGlobals.RoundState.Closed);
            }
            else if (round.submissions.length == 0) {
                return uint256(LibGlobals.RoundState.Abandoned);
            }
            else if (round.winners.length > 0) {
                return uint256(LibGlobals.RoundState.HasWinners);
            }
            return uint256(LibGlobals.RoundState.InReview);
        }
        else if (round.winners.length > 0) {
            return uint256(LibGlobals.RoundState.Closed);
        }
        return uint256(LibGlobals.RoundState.Abandoned);
    }
}
