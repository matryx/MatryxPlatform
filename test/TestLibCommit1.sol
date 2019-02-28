pragma solidity >=0.4.25 <0.6.0;
pragma experimental ABIEncoderV2;

import "../contracts/IToken.sol";
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/LibCommit.sol";

contract TestLibCommit1 {
    MatryxPlatform.Info info;
    MatryxPlatform.Data data;

    bool transferHappened;
    bool transferFromHappened;
    uint256 transferAmount;
    function transfer(address to, uint256 value) public returns (bool)
    {
        transferHappened = true;
        transferAmount = value;
        return transferHappened;
    }
    
    function transferFrom(address from, address to, uint256 value) public returns (bool)
    {
        transferFromHappened = true;
        transferAmount = value;
        return transferFromHappened;
    }

    function allowance(address owner, address spender) public returns (uint256)
    {
        return 1 ether;
    }

    function testGetCommit() public
    {
        bytes32 commitHash = keccak256("commit");
        bytes32 groupHash = keccak256("group");
        string memory content = "QmContent";
        bytes32 contentHash = keccak256(abi.encodePacked(content));
        bytes32 parentHash = keccak256("parent");
        bytes32 child = keccak256("child");

        // create commit
        LibCommit.Commit storage commit = data.commits[commitHash];
        commit.owner = msg.sender;
        commit.timestamp = now;
        commit.groupHash = groupHash;
        commit.commitHash = commitHash;
        commit.content = content;
        commit.value = 5;
        commit.ownerTotalValue = 10;
        commit.totalValue = 20;
        commit.height = 4;
        commit.parentHash = parentHash;
        bytes32[] memory children = new bytes32[](1);
        children[0] = child;
        commit.children = children;

        LibCommit.Commit memory returnedCommit = LibCommit.getCommit(address(this), msg.sender, data, commitHash);

        Assert.equal(commit.owner, returnedCommit.owner, "returned commit has incorrect owner");
        Assert.equal(commit.timestamp, returnedCommit.timestamp, "returned commit has incorrect timestamp");
        Assert.equal(commit.groupHash, returnedCommit.groupHash, "returned commit has incorrect groupHash");
        Assert.equal(commit.commitHash, returnedCommit.commitHash, "returned commit has incorrect commitHash");
        Assert.equal(commit.content, returnedCommit.content, "returned commit has incorrect content");
        Assert.equal(commit.value, returnedCommit.value, "returned commit has incorrect value");
        Assert.equal(commit.ownerTotalValue, returnedCommit.ownerTotalValue, "returned commit has incorrect ownerTotalValue");
        Assert.equal(commit.totalValue, returnedCommit.totalValue, "returned commit has incorrect totalValue");
        Assert.equal(commit.height, returnedCommit.height, "returned commit has incorrect height");
        Assert.equal(commit.parentHash, returnedCommit.parentHash, "returned commit has incorrect parentHash");
        Assert.equal(commit.children[0], returnedCommit.children[0], "returned commit has incorrect children");

        delete data.commits[commitHash];
    }

    function testGetBalance() public
    {
        bytes32 commitHash = keccak256("commit");
        data.commitBalance[commitHash] = 50;

        uint256 commitBalance = LibCommit.getBalance(address(this), msg.sender, data, commitHash);

        Assert.equal(commitBalance, 50, "Commit balance should be 50.");

        delete data.commitBalance[commitHash];
    }

    function testGetCommitByContent() public
    {
        // create commit
        bytes32 commitHash  = keccak256("commit");
        string memory content = "QmContent";
        bytes32 contentHash = keccak256(abi.encodePacked(content));
        bytes32 groupHash = keccak256("group");
        LibCommit.Commit storage commit = data.commits[commitHash];
        commit.owner = msg.sender;
        commit.timestamp = now;
        commit.groupHash = groupHash;
        commit.commitHash = commitHash;
        commit.content = content;
        data.commitHashes[contentHash] = commitHash;

        LibCommit.Commit memory returnedCommit = LibCommit.getCommitByContent(address(this), msg.sender, data, content);
        
        Assert.equal(commit.owner, returnedCommit.owner, "Returned commit's owner is incorrect");
        Assert.equal(commit.timestamp, returnedCommit.timestamp, "Returned commit's timestamp is incorrect");
        Assert.equal(commit.groupHash, returnedCommit.groupHash, "Returned commit's groupHash is incorrect");
        Assert.equal(commit.commitHash, returnedCommit.commitHash, "Returned commit's commitHash is incorrect");
        Assert.equal(commit.content, returnedCommit.content, "Returned commit's content is incorrect");

        delete data.commits[commitHash];
        delete data.commitHashes[contentHash];
    }

    function testGetInitialCommits() public
    {
        bytes32 commit0 = keccak256("commit0");
        bytes32 commit1 = keccak256("commit1");
        bytes32 commit2 = keccak256("commit2");
        data.initialCommits.push(commit0);
        data.initialCommits.push(commit1);
        data.initialCommits.push(commit2);

        bytes32[] memory commits = LibCommit.getInitialCommits(address(this), msg.sender, data);
        Assert.equal(commits[0], commit0, "0th initial commit is incorrect");
        Assert.equal(commits[1], commit1, "1st initial commit is incorrect");
        Assert.equal(commits[2], commit2, "2nd initial commit is incorrect");

        delete data.initialCommits;
    }

    function testGetGroupMembers() public
    {
        bytes32 commitHash = keccak256("commit");
        bytes32 groupHash = keccak256("group");
        data.commits[commitHash].groupHash = groupHash;

        data.groups[groupHash].members.push(msg.sender);
        data.groups[groupHash].members.push(address(this));

        address[] memory members = LibCommit.getGroupMembers(address(this), msg.sender, data, commitHash);

        Assert.equal(members[0], msg.sender, "Group member incorrect.");
        Assert.equal(members[1], address(this), "Group member incorrect.");

        delete data.groups[groupHash];
    }

    function testGetSubmissionsForCommit() public
    {
        bytes32 submission0  = keccak256("submission0");
        bytes32 submission1  = keccak256("submission1");

        // create commit
        bytes32 commitHash  = keccak256("commit");
        string memory content = "QmContent";
        bytes32 contentHash = keccak256(abi.encodePacked(content));
        bytes32 groupHash = keccak256("group");
        LibCommit.Commit storage commit = data.commits[commitHash];
        commit.owner = msg.sender;
        commit.timestamp = now;
        commit.groupHash = groupHash;
        commit.commitHash = commitHash;
        commit.content = content;

        data.commitToSubmissions[commitHash].push(submission0);
        data.commitToSubmissions[commitHash].push(submission1);

        bytes32[] memory submissions = LibCommit.getSubmissionsForCommit(address(this), msg.sender, data, commitHash);

        Assert.equal(submissions[0], submission0, "Commit's 0th commit is incorrect.");
        Assert.equal(submissions[1], submission1, "Commit's 1st commit is incorrect.");

        delete data.commits[commitHash];
        delete data.commitToSubmissions[commitHash];
    }

    function testAddGroupMember() public
    {
        // sender can use matryx
        data.whitelist[msg.sender] = true;
        // create commit
        bytes32 commitHash  = keccak256("commit");
        string memory content = "QmContent";
        bytes32 contentHash = keccak256(abi.encodePacked(content));
        bytes32 groupHash = keccak256("group");
        LibCommit.Commit storage commit = data.commits[commitHash];
        commit.owner = msg.sender;
        commit.timestamp = now;
        commit.groupHash = groupHash;
        commit.commitHash = commitHash;
        commit.content = content;
        // add sender to commit group
        data.groups[groupHash].hasMember[msg.sender] = true;
        data.groups[groupHash].members.push(msg.sender);

        LibCommit.addGroupMember(address(this), msg.sender, info, data, commitHash, address(this));

        Assert.isTrue(data.groups[groupHash].hasMember[address(this)], "Group doesn't include new user.");

        delete data.whitelist[msg.sender];
        delete data.commits[commitHash];
        data.groups[groupHash].hasMember[address(this)] = false;
        data.groups[groupHash].hasMember[msg.sender] = false;
        delete data.groups[groupHash];
    }

    function testAddGroupMembers() public
    {
        // sender can use matryx
        data.whitelist[msg.sender] = true;
        // create commit
        bytes32 commitHash  = keccak256("commit");
        string memory content = "QmContent";
        bytes32 groupHash = keccak256("group");
        LibCommit.Commit storage commit = data.commits[commitHash];
        commit.owner = msg.sender;
        commit.timestamp = now;
        commit.groupHash = groupHash;
        commit.commitHash = commitHash;
        commit.content = content;
        // add sender to commit group
        data.groups[groupHash].hasMember[msg.sender] = true;
        data.groups[groupHash].members.push(msg.sender);

        address[] memory newMembers = new address[](2);
        newMembers[0] = address(this);
        newMembers[1] = address(uint256(address(this))+1);

        LibCommit.addGroupMembers(address(this), msg.sender, info, data, commitHash, newMembers);

        Assert.equal(data.groups[groupHash].members[1], newMembers[0], "1st group member is incorrect");
        Assert.equal(data.groups[groupHash].members[2], newMembers[1], "2nd group member is incorrect");

        delete data.whitelist[msg.sender];
        data.groups[groupHash].hasMember[newMembers[0]] = false;
        data.groups[groupHash].hasMember[newMembers[1]] = false;
        delete data.groups[groupHash];
    }

    function testClaimCommit() public
    {
        // sender can use matryx
        data.whitelist[msg.sender] = true;

        bytes32 commitHash = keccak256(abi.encodePacked("commitHash"));
        LibCommit.claimCommit(address(this), msg.sender, info, data, commitHash);
        
        Assert.equal(data.commitClaims[commitHash], block.number, "Commit claim should be now.");

        delete data.whitelist[msg.sender];
        delete data.commitClaims[commitHash];
    }

    function testCreateFork() public
    {
        // set token
        info.token = address(this);
        // sender can use matryx
        data.whitelist[msg.sender] = true;
        // set total balance
        data.totalBalance = 20;
        // create parent commit
        bytes32 parentHash = keccak256("parent");
        bytes32 parentGroup = keccak256("group");
        string memory parentContent = "QmParentContent";
        LibCommit.Commit storage parent = data.commits[parentHash];
        parent.owner = address(uint256(msg.sender) + 1);
        parent.timestamp = now;
        parent.groupHash = parentGroup;
        parent.commitHash = parentHash;
        parent.content = parentContent;
        parent.value = 5;
        parent.ownerTotalValue = 10;
        parent.totalValue = 20;
        parent.height = 4;
        // commit
        string memory content = "QmContent";
        bytes32 contentHash = keccak256(abi.encodePacked(content));
        bytes32 salt = bytes32(uint256(4));
        bytes32 commitHash = keccak256(abi.encodePacked(msg.sender, salt, content));
        // claim commit
        data.commitClaims[commitHash] = block.number - 1;
        // parent is part of group
        data.groups[parentGroup].hasMember[address(uint256(msg.sender) + 1)] = true;
        data.groups[parentGroup].members.push(address(uint256(msg.sender) + 1));
        
        LibCommit.createCommit(address(this), msg.sender, info, data, parentHash, true, salt, content, 5);
        
        Assert.equal(data.totalBalance, 40, "Total balance should have doubled to 40.");
        Assert.equal(data.commitBalance[parentHash], 20, "Parent commit balance should be 20.");
        Assert.isTrue(transferFromHappened, "Transfer should have happened.");
        Assert.equal(transferAmount, 20, "Transfer amount should have been 20.");
        LibCommit.Commit storage commit = data.commits[commitHash];
        Assert.equal(commit.owner, msg.sender, "Owner of commit should be sender.");
        Assert.equal(commit.timestamp, now, "Commit should have been created now.");
        Assert.notEqual(commit.groupHash, parentGroup, "Group of fork should differ from parent.");
        Assert.isTrue(data.groups[commit.groupHash].hasMember[msg.sender], "Group should include sender.");
        Assert.equal(data.groups[commit.groupHash].members[0], msg.sender, "Sender should be first group member.");
        Assert.equal(commit.content, content, "Commit content should be 'QmContent'.");
        Assert.equal(commit.value, 5, "Commit value should be 5.");
        Assert.equal(commit.ownerTotalValue, 5, "Commit owner's totalValue should be 5.");
        Assert.equal(commit.totalValue, 25, "Commit totalValue should be 25.");
        Assert.equal(commit.height, 5, "Commit height should be 5.");
        Assert.equal(commit.parentHash, parentHash, "Commit parentHash should be keccak256('parent').");

        delete info.token;
        delete data.whitelist[msg.sender];
        delete data.totalBalance;
        delete data.commits[parentHash];
        delete data.commitClaims[commitHash];
        delete data.groups[parentGroup];
        delete data.groups[commit.groupHash];
        delete data.commits[commitHash];
        delete data.commitHashes[contentHash];
        delete transferFromHappened;
        delete transferAmount;
    }

    function testCreateCommitWithParent() public
    {
        // set token
        info.token = address(this);
        // sender can use matryx
        data.whitelist[msg.sender] = true;
        // set total balance
        data.totalBalance = 20;
        // create parent commit
        bytes32 parentHash = keccak256("parent");
        bytes32 parentGroup = keccak256("group");
        string memory parentContent = "QmParentContent";
        LibCommit.Commit storage parent = data.commits[parentHash];
        parent.owner = address(uint256(msg.sender) + 1);
        parent.timestamp = now;
        parent.groupHash = parentGroup;
        parent.commitHash = parentHash;
        parent.content = parentContent;
        parent.value = 6;
        parent.ownerTotalValue = 10;
        parent.totalValue = 20;
        parent.height = 3;
        // commit
        string memory content = "QmContent";
        bytes32 contentHash = keccak256(abi.encodePacked(content));
        bytes32 salt = bytes32(uint256(4));
        bytes32 commitHash = keccak256(abi.encodePacked(msg.sender, salt, content));
        // claim commit
        data.commitClaims[commitHash] = block.number - 1;
        // become part of parent's group
        data.groups[parentGroup].hasMember[msg.sender] = true;
        data.groups[parentGroup].members.push(msg.sender);
        
        LibCommit.createCommit(address(this), msg.sender, info, data, parentHash, false, salt, content, 3);
        
        Assert.equal(data.totalBalance, 20, "Total balance should still be 20.");
        LibCommit.Commit storage commit = data.commits[commitHash];
        Assert.equal(commit.owner, msg.sender, "Owner of commit should be sender.");
        Assert.equal(commit.timestamp, now, "Commit should have been created now.");
        Assert.equal(commit.groupHash, parentGroup, "Commit group should match parent.");
        Assert.equal(commit.content, content, "Commit content should be 'QmContent'.");
        Assert.equal(commit.value, 3, "Commit value should be 3.");
        Assert.equal(commit.ownerTotalValue, 3, "Commit owner's totalValue should be 3.");
        Assert.equal(commit.totalValue, 23, "Commit totalValue should be 23.");
        Assert.equal(commit.height, 4, "Commit height should be 5.");
        Assert.equal(commit.parentHash, parentHash, "Commit parentHash should be keccak256('parent').");

        delete info.token;
        delete data.whitelist[msg.sender];
        delete data.totalBalance;
        delete data.commits[parentHash];
        delete data.commitClaims[commitHash];
        delete data.groups[commit.groupHash];
        delete data.commits[commitHash];
        delete data.commitHashes[contentHash];
        delete transferFromHappened;
        delete transferAmount;
    }

    function testCreateCommitNoParent() public
    {
        // set token
        info.token = address(this);
        // sender can use matryx
        data.whitelist[msg.sender] = true;
        // set total balance
        data.totalBalance = 20;

        // commit
        string memory content = "QmContent";
        bytes32 contentHash = keccak256(abi.encodePacked(content));
        bytes32 salt = bytes32(uint256(4));
        bytes32 commitHash = keccak256(abi.encodePacked(msg.sender, salt, content));
        // claim commit
        data.commitClaims[commitHash] = block.number - 1;
        
        LibCommit.createCommit(address(this), msg.sender, info, data, bytes32(0), false, salt, content, 7);
        
        Assert.equal(data.totalBalance, 20, "Total balance should still be 20.");
        LibCommit.Commit storage commit = data.commits[commitHash];
        Assert.equal(commit.owner, msg.sender, "Owner of commit should be sender.");
        Assert.equal(commit.timestamp, now, "Commit should have been created now.");
        Assert.notEqual(commit.groupHash, bytes32(0), "Group should exist.");
        Assert.isTrue(data.groups[commit.groupHash].hasMember[msg.sender], "Group should include sender.");
        Assert.equal(data.groups[commit.groupHash].members[0], msg.sender, "Sender should be first group member.");
        Assert.equal(commit.content, content, "Commit content should be 'QmContent'.");
        Assert.equal(commit.value, 7, "Commit value should be 5.");
        Assert.equal(commit.ownerTotalValue, 7, "Commit owner's totalValue should be 5.");
        Assert.equal(commit.totalValue, 7, "Commit totalValue should be 5.");
        Assert.equal(commit.height, 1, "Commit height should be 5.");
        Assert.equal(commit.parentHash, bytes32(0), "Commit parentHash should be nussin.");

        delete info.token;
        delete data.whitelist[msg.sender];
        delete data.totalBalance;
        delete data.commitClaims[commitHash];
        delete data.commits[commitHash];
        delete data.commitHashes[contentHash];
        delete transferFromHappened;
        delete transferAmount;
    }
}