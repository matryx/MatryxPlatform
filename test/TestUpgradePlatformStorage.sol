pragma solidity >=0.4.25 <0.6.0;
pragma experimental ABIEncoderV2;

import "../contracts/IToken.sol";
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/MatryxSystem.sol";
import "../contracts/MatryxPlatform.sol";
import "../contracts/LibPlatform.sol";
import "../contracts/test-contracts/LibCommitUpgradeTransition.sol";

contract TestUpgradePlatformStorage {
    // Platform Mock
    MatryxPlatform.Info info;
    MatryxPlatform.Data data;

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

    function getContractMethod(uint256 version, bytes32 cName, bytes32 selector) public returns (MatryxSystem.FnData memory)
    {
        return platformByVersion[version].contracts[cName].fnData[selector];
    }

    // Token Mock
    bool transferHappened;
    uint256 transferAmount;
    function transfer(address to, uint256 value) public returns (bool)
    {
        transferHappened = true;
        transferAmount = value;
        return transferHappened;
    }

    function transferFrom(address from, address to, uint256 value) public view returns (bool)
    {
        return true;
    }

    function allowance(address owner, address spender) public returns (uint256)
    {
        return 1 ether;
    }
    
    function testUpgradeStorage() public
    {
        // set platform's token
        info.token = address(this);
        // sender can use matryx on platform
        data.whitelist[msg.sender] = true;
        // set total platform balance
        data.totalBalance = 20;

        // create version 1 on system
        platformByVersion[1].exists = true;
        allVersions.push(1);
        // set currentVersion to 1 on system
        currentVersion = 1;

        // set MatryxPlatform contract on system
        bytes32 contractName = bytes32("MatryxPlatform");
        address platformAddress = address(new MatryxPlatform(address(this), address(0)));
        platformByVersion[currentVersion].allContracts.push(contractName);
        platformByVersion[currentVersion].contracts[contractName].location = platformAddress;
        // set MatryxPlatform to type 1 on system
        contractType[platformAddress] = 1;

        // set LibPlatform contract on system
        bytes32 libraryName = bytes32("LibCommit");
        address libraryAddress = DeployedAddresses.LibCommitUpgradeTransition();
        platformByVersion[currentVersion].allContracts.push(libraryName);
        platformByVersion[currentVersion].contracts[libraryName].location = libraryAddress;
        // point type 2 contracts to LibCommit on system
        contractTypeToLibraryName[2] = libraryName;
        
        // create parent Commit on Platform
        bytes32 parentHash = keccak256("parent");
        bytes32 groupHash = keccak256("group");
        string memory commitContent = "QmParentContent";
        LibCommit.Commit storage parent = data.commits[parentHash];
        parent.owner = address(uint256(msg.sender) + 1);
        parent.timestamp = now;
        parent.groupHash = groupHash;
        parent.commitHash = parentHash;
        parent.content = commitContent;
        parent.value = 6;
        parent.ownerTotalValue = 6;
        parent.totalValue = 6;
        parent.height = 1;
        // create child Commit on Platform
        bytes32 commitHash = keccak256("commit");
        commitContent = "QmContent";
        LibCommit.Commit storage commit = data.commits[commitHash];
        commit.owner = msg.sender;
        commit.timestamp = now;
        commit.groupHash = groupHash;
        commit.commitHash = commitHash;
        commit.content = commitContent;
        commit.value = 4;
        commit.ownerTotalValue = 4;
        commit.totalValue = 10;
        commit.height = 2;
        commit.parentHash = parentHash;

        // introduce function selector for commit upgrade
        MatryxSystem.FnData memory upgradeFnData;
        bytes32 upgradeCommitSelector;
        bytes32 upgradeCommitModifiedSelector;
        assembly {
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            upgradeCommitSelector := mul(0x8ea0cc12, offset)
            upgradeCommitModifiedSelector := mul(0xfe0fbca3, offset)
        }
        upgradeFnData.modifiedSelector = upgradeCommitModifiedSelector;
        upgradeFnData.injectedParams = new uint256[](1);
        platformByVersion[currentVersion].contracts[libraryName].fnData[upgradeCommitSelector] = upgradeFnData;

        // upgrade Commit through LibPlatformUpgradeTransition
        LibCommitUpgradeTransition.upgradeCommitAndAncestry(address(this), msg.sender, data, commitHash);

        // Assert that all commits in the chain were upgraded
        uint256 commitUpgradeVersion;
        uint256 parentUpgradeVersion;
        
        assembly {
            commitUpgradeVersion := sload(add(commit_slot, 11))
            parentUpgradeVersion := sload(add(parent_slot, 11))
        }

        Assert.equal(commitUpgradeVersion, 1, "Upgraded commit has incorrect new field");
        Assert.equal(parentUpgradeVersion, 1, "Upgraded commit has incorrect new field");
    }
}