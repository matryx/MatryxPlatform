pragma solidity >=0.4.25 <0.6.0;
pragma experimental ABIEncoderV2;

import "../contracts/IToken.sol";
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/MatryxSystem.sol";
import "../contracts/MatryxPlatform.sol";
import "../contracts/LibPlatform.sol";
import "../contracts/test-contracts/LibPlatformUpgraded.sol";

contract TestUpgradePlatform {
    // System Mock
    mapping(address=>uint256) contractType;
    mapping(uint256=>bytes32) contractTypeToLibraryName;

    mapping(uint256=>MatryxSystem.Platform) platformByVersion;
    uint256[] allVersions;
    uint256 currentVersion;

    function getVersion() public view returns (uint256) {
        return currentVersion;
    }

    function getLibraryName(address cAddress) public view returns (bytes32) {
        uint256 cType = contractType[cAddress];
        return contractTypeToLibraryName[cType];
    }

    function getContract(uint256 version, bytes32 cName) public view returns (address) {
        return platformByVersion[version].contracts[cName].location;
    }

    function getContractMethod(uint256 version, bytes32 cName, bytes32 selector) public returns (MatryxSystem.FnData memory) {
        return platformByVersion[version].contracts[cName].fnData[selector];
    }

    // Token Mock
    bool transferHappened;
    uint256 transferAmount;
    function transfer(address to, uint256 value) public returns (bool) {
        transferHappened = true;
        transferAmount = value;
        return transferHappened;
    }

    function transferFrom(address from, address to, uint256 value) public view returns (bool) {
        return true;
    }

    function allowance(address owner, address spender) public returns (uint256) {
        return 1 ether;
    }
    
    function testUpdateInterface() public {
        // create version 1
        uint256 version = 1;
        platformByVersion[version].exists = true;
        allVersions.push(version);
        // set version to 1
        currentVersion = version;

        // set MatryxPlatform contract
        bytes32 contractName = bytes32("MatryxPlatform");
        address platformAddress = address(new MatryxPlatform(address(this), address(0)));
        platformByVersion[version].allContracts.push(contractName);
        platformByVersion[version].contracts[contractName].location = platformAddress;
        // set MatryxPlatform to type 1
        contractType[platformAddress] = 1;

        // set LibPlatform contract
        bytes32 libraryName = bytes32("LibPlatform");
        address libraryAddress = DeployedAddresses.LibPlatformUpgraded();
        platformByVersion[version].allContracts.push(libraryName);
        platformByVersion[version].contracts[libraryName].location = libraryAddress;
        // set type 0 and 1 contracts to LibPlatform
        contractTypeToLibraryName[0] = libraryName;
        contractTypeToLibraryName[1] = libraryName;
        
        // add getInfo function to system
        MatryxSystem.FnData memory getInfoFnData;
        bytes32 getInfoSelector;
        bytes32 getInfoModifiedSelector;
        assembly {
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            getInfoSelector := mul(0x5a9b0b89, offset)
            getInfoModifiedSelector := mul(0x2c27d013, offset)
        }
        getInfoFnData.modifiedSelector = getInfoModifiedSelector;
        getInfoFnData.injectedParams = new uint256[](1);
        platformByVersion[version].contracts[libraryName].fnData[getInfoSelector] = getInfoFnData;
        
        // system.addContractMethod(1, stb('LibPlatform'), '0xdf6cee4c', ['0x74492d8f', [0], []], { gasLimit: 3e6 })
        MatryxSystem.FnData memory setTokenFnData;
        bytes32 setTokenSelector;
        bytes32 setTokenModifiedSelector;
        assembly {
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            setTokenSelector := mul(0x144fa6d7, offset)
            setTokenModifiedSelector := mul(0x79df4fdc, offset)
        }
        setTokenFnData.modifiedSelector = setTokenModifiedSelector;
        setTokenFnData.injectedParams = new uint256[](1);
        platformByVersion[version].contracts[libraryName].fnData[setTokenSelector] = setTokenFnData;

        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        MatryxPlatform.Info memory info = platform.getInfo();

        Assert.equal(info.token, address(0), "Token should be zero before being set.");

        IPlatformUpgraded newPlatform = IPlatformUpgraded(platformAddress);
        newPlatform.setToken(msg.sender);

        info = newPlatform.getInfo();
        Assert.equal(info.token, msg.sender, "Token address should have been set.");
    }
}