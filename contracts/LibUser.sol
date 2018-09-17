pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

library LibUser {
    struct UserData {
        bool      exists;
        uint256   reputation;
        uint256   totalSpent;
        uint256   totalWinnings;
        address[] tournaments;
        address[] submissions;
        address[] tournamentsEntered;
        address[] collaboratedWith;
        address[] contributed;
        address[] viewedFiles;
    }
}
