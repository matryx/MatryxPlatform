pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";

contract MatryxProxy is Ownable {
    struct Platform {
        bool exists;
        mapping(bytes32=>ContractData) contracts; // 'LibTournament' => ContractData
        bytes32[] allContracts;
    }

    // Platform, LibTournament...
    struct ContractData {
        address location;
        bool isLibrary;
        mapping(bytes32=>bytes32[]) fnInjectedParams; // fn selector => what storage slot to insert?
        mapping(bytes32=>bytes32) fnModifiedSelector; // fn selector => modified fn selector
    }

    // examples:
    // Tournament.selectWinners(winnerData) => call to Platform => delegatecall to LibTournament.selectWinners(TournamentData storage, winnerData)

    // Platform.Tournament_selectWinners(winnerData) => delegatecall to LibTournament.Tournament_selectWinners(TournamentData storage, winnerData)
    // Tournament.addFunds(mtx) => Platform calls LibTournament.addFunds(tokenAddress, mtx)

    // note to future self:
    // must manually set these!!!

    mapping(uint256=>Platform) platformByVersion;
    uint256[] allVersions;
    uint256 currentVersion;

    function createVersion(uint256 _version) public onlyOwner {
        platformByVersion[_version].exists = true;
        allVersions.push(_version);
    }

    function setCurrentVersion(uint256 _version) public onlyOwner {
        currentVersion = _version;
    }

    function getCurrentVersion() public view returns (uint256 _currentVersion) {
        return currentVersion;
    }

    function getAllVersions() public view returns (uint256[]) {
        return allVersions;
    }

    function setContract(bytes32 _name, address _contractAddress, uint256 _version) public onlyOwner {
        require(platformByVersion[_version].exists);

        if (platformByVersion[_version].contracts[_name] == 0) {
            platformByVersion[_version].allContracts.push(_name);
        }

        platformByVersion[_version].contracts[_name] = _contractAddress;
    }

    function getContract(bytes32 _name) public view returns (address) {
        return platformByVersion[currentVersion].contracts[_name];
    }

    function getContractAtVersion(bytes32 _name, uint256 _version) public view returns (address) {
        return platformByVersion[_version].contracts[_name];
    }
}
