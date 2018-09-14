pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";

contract MatryxProxy is Ownable() {
    struct Platform {
        bool exists;
        mapping(bytes32=>ContractData) contracts; // 'LibTournament' => ContractData
        bytes32[] allContracts;
    }

    struct FnData {
        bytes32 modifiedSelector; // modified fn selector
        uint256[] injectedParams; // what storage slots to insert
        uint256[] dynamicParams;  // what params are dynamic
    }

    // Platform, LibTournament...
    struct ContractData {
        address location;
        mapping(bytes32=>FnData) fnData;
    }

    // examples:
    // Tournament.selectWinners(winnerData) => call to Platform => proxy lookup => delegatecall to LibTournament.selectWinners(TournamentData storage, winnerData)

    // note to future self:
    // must manually set these!!!

    enum ContractType { Unknown, Platform, Tournament, Round, Submission }
    mapping(address=>ContractType) contractType;

    mapping(uint256=>Platform) platformByVersion;
    uint256[] allVersions;
    uint256 currentVersion;

    modifier onlyOwnerOrPlatform {
        require(msg.sender == owner || contractType[msg.sender] == ContractType.Platform);
        _;
    }

    function createVersion(uint256 _version) public onlyOwner {
        require(!platformByVersion[_version].exists);
        platformByVersion[_version].exists = true;
        allVersions.push(_version);
    }

    function setVersion(uint256 _version) public onlyOwner {
        currentVersion = _version;
    }

    function getVersion() public view returns (uint256 _currentVersion) {
        return currentVersion;
    }

    function getAllVersions() public view returns (uint256[]) {
        return allVersions;
    }

    function setContract(uint256 _version, bytes32 _contractName, address _contractAddress) public onlyOwner {
        require(platformByVersion[_version].exists);

        if (platformByVersion[_version].contracts[_contractName].location == 0x0) {
            platformByVersion[_version].allContracts.push(_contractName);
        }

        if (_contractName == "MatryxPlatform") {
            contractType[_contractAddress] = ContractType.Platform;
        }

        platformByVersion[_version].contracts[_contractName].location = _contractAddress;
    }

    function getContract(uint256 _version, bytes32 _contractName) public view returns (address) {
        return platformByVersion[_version].contracts[_contractName].location;
    }

    function addContractMethod(uint256 _version, bytes32 _contractName, bytes32 _selector, FnData _fnData) public onlyOwner {
        require(platformByVersion[_version].exists);
        require(platformByVersion[_version].contracts[_contractName].location != 0x0);
        platformByVersion[_version].contracts[_contractName].fnData[_selector] = _fnData;
    }

    function getContractMethod(uint256 _version, bytes32 _contractName, bytes32 _selector) public view returns (FnData) {
        return platformByVersion[_version].contracts[_contractName].fnData[_selector];
    }

    function setContractType(address _contractAddress, ContractType _type) public {//onlyOwnerOrPlatform {
        contractType[_contractAddress] = _type;
    }

    function getContractType(address _contractAddress) public view returns (ContractType) {
        return contractType[_contractAddress];
    }
}
