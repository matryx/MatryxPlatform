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

    /// @dev Create a new version of Platform
    function createVersion(uint256 _version) public onlyOwner {
        require(!platformByVersion[_version].exists);
        platformByVersion[_version].exists = true;
        allVersions.push(_version);
    }

    /// @dev Set the current version of Platform
    function setVersion(uint256 _version) public onlyOwner {
        currentVersion = _version;
    }

    /// @dev Get the current version of Platform
    function getVersion() public view returns (uint256 _currentVersion) {
        return currentVersion;
    }

    /// @dev Get all versions of the Platform
    function getAllVersions() public view returns (uint256[]) {
        return allVersions;
    }

    /// @dev Set a contract address for a contract by a given name
    /// @param _version          Version of the Platform this contract belongs to
    /// @param _contractName     Name of the contract
    /// @param _contractAddress  The name of the contract we want an address for.
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

    /// @dev Returns the address of a contract given its name.
    /// @param _version      The version of the platform to lookup the address on.
    /// @param _contractName The name of the contract we want an address for.
    /// @return              Address of the contract
    function getContract(uint256 _version, bytes32 _contractName) public view returns (address) {
        return platformByVersion[_version].contracts[_contractName].location;
    }

    /// @dev Register a contract method for a contract by its name
    /// @param _version       The version of The name of the contract we want an address for.
    /// @param _contractName  The name of the contract we want an address for.
    /// @param _selector      Hash of the method to register to the contract (keccak256)
    /// @param _fnData        Calldata transformation information for library delegatecall
    function addContractMethod(uint256 _version, bytes32 _contractName, bytes32 _selector, FnData _fnData) public onlyOwner {
        require(platformByVersion[_version].exists);
        require(platformByVersion[_version].contracts[_contractName].location != 0x0);
        platformByVersion[_version].contracts[_contractName].fnData[_selector] = _fnData;
    }

    /// @dev Gets calldata transformation information for a library name and function selector
    /// @param _version       The version of The name of the contract we want an address for.
    /// @param _contractName  The name of the contract we want an address for.
    /// @param _selector      Hash of the method to register to the contract (keccak256)
    /// @return               Calldata transformation information for library delegatecall
    function getContractMethod(uint256 _version, bytes32 _contractName, bytes32 _selector) public view returns (FnData) {
        return platformByVersion[_version].contracts[_contractName].fnData[_selector];
    }

    /// @dev Associates a contract address with a type
    function setContractType(address _contractAddress, ContractType _type) public onlyOwnerOrPlatform {
        contractType[_contractAddress] = _type;
    }

    /// @dev Gets the associated type for a contract address
    function getContractType(address _contractAddress) public view returns (ContractType) {
        return contractType[_contractAddress];
    }
}
