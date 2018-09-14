pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxRouter.sol";

import "./MatryxPlatform.sol";

contract MatryxSubmission is MatryxRouter {
    constructor (uint256 _version, address _proxy) MatryxRouter(_version, _proxy) public {}
}

interface IMatryxSubmission {
    function getTournament() public view returns (address);
    function getRound() public view returns (address);
}

library LibSubmission {
    struct SubmissionData {
        address tournament;
        address round;
        bytes32[3] title;
        bytes32[2] descriptionHash;
        bytes32[2] fileHash;
        uint256 timeSubmitted;
        uint256 timeUpdated;
    }

    function getTournament(address self, MatryxPlatform.Data storage data) public view returns (address) {
        address round = data.submissions[self].round;
        return data.rounds[round].tournament;
    }

    function getRound(address self, MatryxPlatform.Data storage data) public view returns (address) {
        return data.submissions[self].round;
    }
}
