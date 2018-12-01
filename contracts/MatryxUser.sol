pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxPlatform.sol";

contract MatryxUser {
    struct Info {
        uint256 version;
        address system;
    }

    Info info;

    constructor(uint256 _version, address _system) public {
        info.version = _version;
        info.system = _system;
    }

    /// @dev
    /// Gets the address of the current version of Platform and forwards the
    /// received calldata to this address. Injects msg.sender at the front so
    /// Platform and libraries can know calling address
    function () public {
        assembly {
            let ptr := mload(0x40)
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let platform := 0x4d6174727978506c6174666f726d000000000000000000000000000000000000
            let version := sload(info_slot)
            let system := sload(add(info_slot, 1))

            // prepare for lookup platform from MSC
            mstore(ptr, mul(0xc53cfd9a, offset))                                // getContract(uint256,bytes32)
            mstore(add(ptr, 0x04), version)                                     // arg 0 - version of this forwarder
            mstore(add(ptr, 0x24), platform)                                    // arg 1 - 'MatryxPlatform'

            // call getContract to get MatryxPlatform from MSC
            let res := call(gas, system, 0, ptr, 0x44, 0, 0x20)                 // call MatryxSystem.getContract
            if iszero(res) { revert(0, 0) }                                     // safety check
            platform := mload(0)                                                // load platform address

            // forward method to MatryxPlatform, injecting msg.sender
            calldatacopy(ptr, 0, 0x04)                                          // copy signature
            mstore(add(ptr, 0x04), caller)                                      // inject msg.sender
            mstore(add(ptr, 0x24), version)                                     // inject version
            calldatacopy(add(ptr, 0x44), 0x04, sub(calldatasize, 0x04))         // copy calldata for forwarding
            res := call(gas, platform, 0, ptr, add(calldatasize, 0x40), 0, 0)   // forward method to MatryxPlatform
            if iszero(res) { revert(0, 0) }                                     // safety check

            // forward returndata to caller
            returndatacopy(ptr, 0, returndatasize)                              // copy returndata into ptr
            return(ptr, returndatasize)                                         // return returndata from forwarded call
        }
    }
}

interface IMatryxUser {
    function getData(address user) external view returns (LibUser.UserData);
    function getTimeInMatryx(address user) external view returns (uint256);
    function getVotes(address user) external view returns (uint256, uint256);
    function getTotalSpent(address user) external view returns (uint256);
    function getTotalWinnings(address user) external view returns (uint256);
    function getTournaments(address user) external view returns (address[]);
    function getTournamentsEntered(address user) external view returns (address[]);
    function getSubmissions(address user) external view returns (address[]);
    function getContributedTo(address user) external view returns (address[]);
    function getUnlockedFiles(address user) external view returns (address[]);
}

library LibUser {
    struct UserData {
        bool      exists;
        uint256   timeEntered;
        uint256   positiveVotes;
        uint256   negativeVotes;
        uint256   totalSpent;
        uint256   totalWinnings;
        address[] tournaments;
        address[] tournamentsEntered;
        address[] submissions;
        address[] contributedTo;
        address[] unlockedFiles;
    }

    function getData(address, address, MatryxPlatform.Data storage data, address user) public view returns (LibUser.UserData) {
        return data.users[user];
    }

    function getTimeInMatryx(address, address, MatryxPlatform.Data storage data, address user) public view returns (uint256) {
        return now - data.users[user].timeEntered;
    }

    function getVotes(address, address, MatryxPlatform.Data storage data, address user) public view returns (uint256, uint256) {
        return (data.users[user].positiveVotes, data.users[user].negativeVotes);
    }

    function getTotalSpent(address, address, MatryxPlatform.Data storage data, address user) public view returns (uint256) {
        return data.users[user].totalSpent;
    }

    function getTotalWinnings(address, address, MatryxPlatform.Data storage data, address user) public view returns (uint256) {
        return data.users[user].totalWinnings;
    }

    function getTournaments(address, address, MatryxPlatform.Data storage data, address user) public view returns (address[]) {
        return data.users[user].tournaments;
    }

    function getTournamentsEntered(address, address, MatryxPlatform.Data storage data, address user) public view returns (address[]) {
        return data.users[user].tournamentsEntered;
    }

    function getSubmissions(address, address, MatryxPlatform.Data storage data, address user) public view returns (address[]) {
        return data.users[user].submissions;
    }

    function getContributedTo(address, address, MatryxPlatform.Data storage data, address user) public view returns (address[]) {
        return data.users[user].contributedTo;
    }

    function getUnlockedFiles(address, address, MatryxPlatform.Data storage data, address user) public view returns (address[]) {
        return data.users[user].unlockedFiles;
    }

}
