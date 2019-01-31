pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./MatryxPlatform.sol";
import "./MatryxForwarder.sol";

contract MatryxUser is MatryxForwarder {
    constructor(uint256 _version, address _system) MatryxForwarder(_version, _system) public {}
}

interface IMatryxUser {
    function getData(address user) external view returns (LibUser.UserData memory);
    function getTimeInMatryx(address user) external view returns (uint256);
    function getTotalSpent(address user) external view returns (uint256);
    function getTotalCashedOut(address user) external view returns (uint256);
    function getTournaments(address user) external view returns (address[] memory);
    function getTournamentsEntered(address user) external view returns (address[] memory);
    function getSubmissions(address user) external view returns (bytes32[] memory);
    // function getSubmissionsByTournament(address user, address tAddress) external view returns (bytes32[] memory);
}

library LibUser {
    struct UserData {
        bool      exists;
        uint256   timeEntered;
        uint256   totalSpent;
        uint256   totalCashedOut;
        address[] tournaments;
        address[] tournamentsEntered;
        bytes32[] submissions;
    }

    function getData(address, address, MatryxPlatform.Data storage data, address user) public view returns (LibUser.UserData memory) {
        return data.users[user];
    }

    function getTimeInMatryx(address, address, MatryxPlatform.Data storage data, address user) public view returns (uint256) {
        return now - data.users[user].timeEntered;
    }

    function getTotalSpent(address, address, MatryxPlatform.Data storage data, address user) public view returns (uint256) {
        return data.users[user].totalSpent;
    }

    function getTotalCashedOut(address, address, MatryxPlatform.Data storage data, address user) public view returns (uint256) {
        return data.users[user].totalCashedOut;
    }

    function getTournaments(address, address, MatryxPlatform.Data storage data, address user) public view returns (address[] memory) {
        return data.users[user].tournaments;
    }

    function getTournamentsEntered(address, address, MatryxPlatform.Data storage data, address user) public view returns (address[] memory) {
        return data.users[user].tournamentsEntered;
    }

    function getSubmissions(address, address, MatryxPlatform.Data storage data, address user) public view returns (bytes32[] memory) {
        return data.users[user].submissions;
    }

    // function getSubmissionsByTournament(address, address, MatryxPlatform.Data storage data, address user, address tAddress) public view returns (address[] memory) {
    //     address[] storage submissions = data.users[user].submissions;

    //     uint256 tSubCount = 0;
    //     for (uint256 i = 0; i < submissions.length; i++) {
    //         if (data.submissions[submissions[i]].info.tournament == tAddress) {
    //             tSubCount++;
    //         }
    //     }

    //     uint256 j = 0;
    //     address[] memory tSubs = new address[](tSubCount);

    //     for (uint256 i = 0; i < submissions.length; i++) {
    //         if (data.submissions[submissions[i]].info.tournament == tAddress) {
    //             tSubs[j++] = submissions[i];
    //         }
    //     }

    //     return tSubs;
    // }
}
