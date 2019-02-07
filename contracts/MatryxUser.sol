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
    function getTotalWithdrawn(address user) external view returns (uint256);
    function getTournaments(address user) external view returns (address[] memory);
    function getTournamentsEntered(address user) external view returns (address[] memory);
    function getSubmissions(address user) external view returns (bytes32[] memory);
}

library LibUser {
    struct UserData {
        bool      entered;
        bool      banned;
        uint256   timeEntered;
        uint256   totalSpent;
        uint256   totalWithdrawn;
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

    function getTotalWithdrawn(address, address, MatryxPlatform.Data storage data, address user) public view returns (uint256) {
        return data.users[user].totalWithdrawn;
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
}
