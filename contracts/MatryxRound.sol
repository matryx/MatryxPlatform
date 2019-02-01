pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./LibGlobals.sol";

import "./MatryxSystem.sol";
import "./MatryxPlatform.sol";
import "./MatryxForwarder.sol";
import "./MatryxTournament.sol";

contract MatryxRound is MatryxForwarder {
    constructor (uint256 _version, address _system) MatryxForwarder(_version, _system) public {}
}

interface IMatryxRound {
    function getVersion() external view returns (uint256);
    function getTournament() external view returns (address);
    function getStart() external view returns (uint256);
    function getEnd() external view returns (uint256);
    function getReview() external view returns (uint256);
    function getBounty() external view returns (uint256);
    function getBalance() external view returns (uint256);
    function getSubmission(bytes32 submissionHash) external view returns (LibTournament.SubmissionData memory submissionData);
    function getSubmissions() external view returns (bytes32[] memory);
    function getData() external view returns (LibRound.RoundReturnData memory);

    function getSubmissionCount() external view returns (uint256);
    function getWinningSubmissions() external view returns (bytes32[] memory);

    function getState() external view returns (uint256);
}

library LibRound {

    using SafeMath for uint256;

    struct RoundInfo {
        uint256 version;
        address tournament;
        bytes32[] allSubmissions;
        LibRound.WinnersData winners;
        bool closed;
    }

    // All information needed for creation of Round
    struct RoundDetails {
        uint256 start;
        uint256 end;
        uint256 review;
        uint256 bounty;
    }

    // All information needed to choose winning submissions
    struct WinnersData {
        bytes32[] submissions;
        uint256[] distribution;
        uint256 action;
    }

    struct RoundData {
        LibRound.RoundInfo info;
        LibRound.RoundDetails details;

        mapping(bytes32=>bool) isSubmission;
        mapping(bytes32=>LibTournament.SubmissionData) submissions;
    }

    // All state data and details of Round
    struct RoundReturnData {
        LibRound.RoundInfo info;
        LibRound.RoundDetails details;
    }

    /// @dev Returns the version of this Round
    function getVersion(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].info.version;
    }

    /// @dev Returns the Tournament address of this Round
    function getTournament(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.rounds[self].info.tournament;
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

    /// @dev Returns the MTX balance of this Round
    function getBalance(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.balanceOf[self];
    }

    function getSubmission(address self, address, MatryxPlatform.Data storage data, bytes32 submissionHash) public view returns (LibTournament.SubmissionData memory submissionData) {
        return data.rounds[self].submissions[submissionHash];
    }

    /// @dev Returns all Submissions of this Round
    function getSubmissions(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[] memory) {
        return data.rounds[self].info.allSubmissions;
    }

    /// @dev Returns the data struct of this Round
    function getData(address self, address, MatryxPlatform.Data storage data) public view returns (LibRound.RoundReturnData memory) {
        LibRound.RoundReturnData memory round;
        round.info = data.rounds[self].info;
        round.details = data.rounds[self].details;
        return round;
    }

    /// @dev Returns the total number of Submissions in this Round
    function getSubmissionCount(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].info.allSubmissions.length;
    }

    /// @dev Returns the addresses of all winning Submissions of this Round
    function getWinningSubmissions(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[] memory) {
        return data.rounds[self].info.winners.submissions;
    }

    /// @dev Returns the current state of this Round
    function getState(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        LibRound.RoundData storage round = data.rounds[self];

        if (now < round.details.start) {
            return uint256(LibGlobals.RoundState.NotYetOpen);
        }
        else if (now < round.details.end) {
            if (data.balanceOf[self] == 0) {
                return uint256(LibGlobals.RoundState.Unfunded);
            }
            return uint256(LibGlobals.RoundState.Open);
        }
        else if (now < round.details.end.add(round.details.review)) {
            if (round.info.closed) {
                return uint256(LibGlobals.RoundState.Closed);
            }
            else if (round.info.allSubmissions.length == 0) {
                return uint256(LibGlobals.RoundState.Abandoned);
            }
            else if (round.info.winners.submissions.length > 0) {
                return uint256(LibGlobals.RoundState.HasWinners);
            }
            return uint256(LibGlobals.RoundState.InReview);
        }
        else if (round.info.winners.submissions.length > 0) {
            return uint256(LibGlobals.RoundState.Closed);
        }
        return uint256(LibGlobals.RoundState.Abandoned);
    }
}
