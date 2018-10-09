pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";

contract MatryxSystem is Ownable() {
    // Contains info for a version of Platform
    struct Platform {
        bool exists;
        mapping(bytes32=>ContractData) contracts;
        bytes32[] allContracts;
    }

    // Used to transform calls on a MatryxTrinity to its relevant library
    struct FnData {
        bytes32 modifiedSelector; // modified fn selector
        uint256[] injectedParams; // what storage slots to insert
        uint256[] dynamicParams;  // what params are dynamic
    }

    // Stores information about a currently deployed contract or library
    struct ContractData {
        address location;
        mapping(bytes32=>FnData) fnData;
    }

    mapping(address=>uint256) contractType;
    mapping(uint256=>bytes32) contractTypeToLibraryName;

    mapping(uint256=>Platform) platformByVersion;
    uint256[] allVersions;
    uint256 currentVersion;

    modifier onlyOwnerOrPlatform {
        bool isOwner = msg.sender == owner;
        bool isPlatform = contractType[msg.sender] == uint256(LibSystem.ContractType.Platform);
        require(isOwner || isPlatform, "Must be owner or Platform");
        _;
    }

    /// @dev Checks the validity of a contract address
    function isContract(address _address) private view returns(bool) {
        uint256 _size;
        assembly { _size := extcodesize(_address) }
        return _size > 0;
    }

    /// @dev Create a new version of Platform
    function createVersion(uint256 version) public onlyOwner {
        require(!platformByVersion[version].exists, "Version already exists");
        platformByVersion[version].exists = true;
        allVersions.push(version);
    }

    /// @dev Set the current version of Platform
    function setVersion(uint256 version) public onlyOwner {
        currentVersion = version;
    }

    /// @dev Get the current version of Platform
    function getVersion() public view returns (uint256) {
        return currentVersion;
    }

    /// @dev Get all versions of Platform
    function getAllVersions() public view returns (uint256[]) {
        return allVersions;
    }

    /// @dev Set a contract address for a contract by a given name
    /// @param version   Version of Platform this contract belongs to
    /// @param cName     Name of the contract we want to set an address for
    /// @param cAddress  Address of the contract
    function setContract(uint256 version, bytes32 cName, address cAddress) public onlyOwner {
        require(platformByVersion[version].exists, "No such version");
        require(isContract(cAddress), "Invalid contract address");

        if (platformByVersion[version].contracts[cName].location == 0x0) {
            platformByVersion[version].allContracts.push(cName);
        }

        platformByVersion[version].contracts[cName].location = cAddress;
    }

    /// @dev Returns the address of a contract given its name
    /// @param version  Version of Platform to lookup the address on
    /// @param cName    Name of the contract we want an address for
    /// @return         Address of the contract
    function getContract(uint256 version, bytes32 cName) public view returns (address) {
        address cAddress = platformByVersion[version].contracts[cName].location;
        require(isContract(cAddress), "Invalid contract address");

        return cAddress;
    }

    /// @dev Register a contract method for a contract by its name
    /// @param version   Version of Platform for contract method association
    /// @param cName     Name of the contract we want an address for
    /// @param selector  Hash of the method signature to register to the contract (keccak256)
    /// @param fnData    Calldata transformation information for library delegatecall
    function addContractMethod(uint256 version, bytes32 cName, bytes32 selector, FnData fnData) public onlyOwner {
        require(platformByVersion[version].exists, "No such version");
        address cAddress = platformByVersion[version].contracts[cName].location;
        require(isContract(cAddress), "Invalid contract address");

        platformByVersion[version].contracts[cName].fnData[selector] = fnData;
    }

    /// @dev Gets calldata transformation information for a library name and function selector
    /// @param version   Version of Platform for the method request
    /// @param cName     Name of the contract we want an address for
    /// @param selector  Hash of the method signature to register to the contract (keccak256)
    /// @return          Calldata transformation information for library delegatecall
    function getContractMethod(uint256 version, bytes32 cName, bytes32 selector) public view returns (FnData) {
        address cAddress = platformByVersion[version].contracts[cName].location;
        require(isContract(cAddress), "Invalid contract address");

        return platformByVersion[version].contracts[cName].fnData[selector];
    }

    /// @dev Associates a contract address with a type
    /// @param cAddress  Address of the contract we want to set the type
    /// @param cType     Type we want to associate the contract address with
    function setContractType(address cAddress, uint256 cType) public onlyOwnerOrPlatform {
        require(isContract(cAddress), "Invalid contract address");
        contractType[cAddress] = cType;
    }

    /// @dev Gets the associated type for a contract address
    /// @param cAddress  Address of the contract we want to get the type for
    function getContractType(address cAddress) public view returns (uint256) {
        return contractType[cAddress];
    }

    /// @dev Associates a contract type with a library name
    /// @param cType  Contract type
    /// @param lName  Library name
    function setLibraryName(uint256 cType, bytes32 lName) public onlyOwnerOrPlatform {
        contractTypeToLibraryName[cType] = lName;
    }

    /// @dev Returns the library name for a given contract type
    /// @param cType  Contract type
    /// @return       Library name
    function getLibraryName(uint256 cType) public view returns (bytes32) {
        return contractTypeToLibraryName[cType];
    }
}

library LibSystem {
    enum ContractType { Unknown, Platform, User, Tournament, Round, Submission }
}