pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./LibGlobals.sol";

import "./MatryxSystem.sol";
import "./MatryxPlatform.sol";
import "./MatryxTrinity.sol";
import "./MatryxTournament.sol";

contract MatryxRound is MatryxTrinity {
    constructor (uint256 _version, address _system) MatryxTrinity(_version, _system) public {}
}

interface IMatryxRound {
    function transferFrom(address, address, uint256) external;
    function transferTo(address, address, uint256) external;

    function getVersion() external view returns (uint256);
    function getTournament() external view returns (address);
    function getStart() external view returns (uint256);
    function getEnd() external view returns (uint256);
    function getReview() external view returns (uint256);
    function getBounty() external view returns (uint256);
    function getBalance() external view returns (uint256);
    function getSubmissions(uint256, uint256) external view returns (address[]);
    function getData() external view returns (LibRound.RoundReturnData);

    function getSubmissionCount() external view returns (uint256);
    function getWinningSubmissions() external view returns (address[]);

    function getState() external view returns (uint256);
}

library LibRound {
    using SafeMath for uint256;

    struct RoundInfo {
        uint256 version;
        address tournament;
        address[] submissions;
        WinnersData winners;
        bool closed;
    }

    // All information needed for creation of Round
    struct RoundDetails {
        // bytes32[2] pKHash;
        uint256 start;
        uint256 end;
        uint256 review;
        uint256 bounty;
    }

    // All information needed to choose winning submissions
    struct WinnersData {
        // bytes32[2] sKHash;
        address[] submissions;
        uint256[] distribution;
        uint256 action;
    }

    struct RoundData {
        RoundInfo info;
        RoundDetails details;

        mapping(address=>bool) isSubmission;
        address[] judgedSubmissions;
        mapping(address=>bool) judgedSubmission;
        mapping(address=>bool) judgedRound;
    }

    // All state data and details of Round
    struct RoundReturnData {
        RoundInfo info;
        RoundDetails details;
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
    function getBalance(address self, address, MatryxPlatform.Info storage info) public view returns (uint256) {
        return IMatryxToken(info.token).balanceOf(self);
    }

    /// @dev Returns all Submissions of this Round or a given subset of them
    /// @param self        Address of this Round
    /// @param info        Info struct on Platform
    /// @param data        Data struct on Platform
    /// @param startIndex  Starting index of subset of Submissions to return
    /// @param count       Number of Submissions to return from startIndex
    function getSubmissions(address self, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, uint256 startIndex, uint256 count) public view returns (address[]) {
        address LibUtils = IMatryxSystem(info.system).getContract(info.version, "LibUtils");
        address[] storage submissions = data.rounds[self].info.submissions;

        assembly {
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let ptr := mload(0x40)

            mstore(ptr, mul(0xe79eda2c, offset))                                // getSubArray(bytes32[] storage,uint256,uint256)
            mstore(add(ptr, 0x04), submissions_slot)                            // data.rounds[self].info.submissions
            mstore(add(ptr, 0x24), startIndex)                                  // arg 0 - startIndex
            mstore(add(ptr, 0x44), count)                                       // arg 1 - count

            let res := delegatecall(gas, LibUtils, ptr, 0x64, 0, 0)             // call LibUtils.getSubArray
            if iszero(res) { revert(0, 0) }                                     // safety check

            returndatacopy(ptr, 0, returndatasize)                              // copy result into mem
            return(ptr, returndatasize)                                         // return result
        }
    }

    /// @dev Returns the data struct of this Round
    function getData(address self, address, MatryxPlatform.Data storage data) public view returns (LibRound.RoundReturnData) {
        RoundReturnData memory round;
        round.info = data.rounds[self].info;
        round.details = data.rounds[self].details;
        return round;
    }

    /// @dev Returns the total number of Submissions in this Round
    function getSubmissionCount(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].info.submissions.length;
    }

    /// @dev Returns the addresses of all winning Submissions of this Round
    function getWinningSubmissions(address self, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.rounds[self].info.winners.submissions;
    }

    /// @dev Returns the current state of this Round
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
            if (round.info.closed) {
                return uint256(LibGlobals.RoundState.Closed);
            }
            else if (round.info.submissions.length == 0) {
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
