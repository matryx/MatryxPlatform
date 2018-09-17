pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxForwarder.sol";

import "./MatryxPlatform.sol";

contract MatryxRound is MatryxForwarder {
    constructor (uint256 _version, address _proxy) MatryxForwarder(_version, _proxy) public {}
}

interface IMatryxRound {
    function getTournament() external view returns (address);

    function getStart() external view returns (uint256);
    function getEnd() external view returns (uint256);
    function getReview() external view returns (uint256);
    function getBounty() external view returns (uint256);

    function getSubmissions() external view returns (address[]);
    function getData() external view returns (LibRound.RoundData);
}

library LibRound {
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
        bool closed;
    }

    /// @dev Returns the Tournament address of this Round
    function getTournament(address self, address sender, MatryxPlatform.Data storage data) public view returns (address) {
        return data.rounds[self].tournament;
    }

    /// @dev Returns the start time of this Round (unix epoch time in seconds)
    function getStart(address self, address sender, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].details.start;
    }

    /// @dev Returns the end time of this Round (unix epoch time in seconds)
    function getEnd(address self, address sender, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].details.end;
    }

    /// @dev Returns the duration of the review period of this Round
    function getReview(address self, address sender, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].details.review;
    }

    /// @dev Returns the bounty of this Round
    function getBounty(address self, address sender, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.rounds[self].details.bounty;
    }

    /// @dev Returns all Submissions of this Round
    function getSubmissions(address self, address sender, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.rounds[self].submissions;
    }

    /// @dev Returns the data struct of this Round
    function getData(address self, address sender, MatryxPlatform.Data storage data) public view returns (LibRound.RoundData) {
        return data.rounds[self];
    }
}
