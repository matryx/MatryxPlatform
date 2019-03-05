pragma solidity >=0.4.25 <0.6.0;
pragma experimental ABIEncoderV2;

import "../contracts/IToken.sol";
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/LibCommit.sol";

contract TestLibCommit2 {

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

    function testCreateSubmission() public
    {
        // set token
        info.token = address(this);
        // sender can use matryx
        data.whitelist[msg.sender] = true;
        // set total balance
        data.totalBalance = 20;

        // tournament exists, round is Open
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 1;
        roundZero.details.duration = 61;
        roundZero.details.bounty = 10;
        // tournament entry fee paid
        data.tournaments[address(this)].entryFeePaid[msg.sender].exists = true;

        // commit
        string memory commitContent = "QmContent";
        string memory submissionContent = "QmSubmissionContent";
        bytes32 contentHash = keccak256(abi.encodePacked(commitContent));
        bytes32 salt = bytes32(uint256(4));
        bytes32 commitHash = keccak256(abi.encodePacked(msg.sender, salt, commitContent));
        // claim commit
        data.commitClaims[commitHash] = now - 1;

        LibCommit.createSubmission(address(this), msg.sender, info, data, address(this), submissionContent, bytes32(0), false, salt, commitContent, 8);

        // Commit
        Assert.equal(data.totalBalance, 20, "Total balance should still be 20.");
        LibCommit.Commit storage commit = data.commits[commitHash];
        Assert.equal(commit.owner, msg.sender, "Owner of commit should be sender.");
        Assert.equal(commit.timestamp, now - 1, "Commit timestamp should be commit claim time.");
        Assert.notEqual(commit.groupHash, bytes32(0), "Group should exist.");
        Assert.isTrue(data.groups[commit.groupHash].hasMember[msg.sender], "Group should include sender.");
        Assert.equal(data.groups[commit.groupHash].members[0], msg.sender, "Sender should be first group member.");
        Assert.equal(commit.content, commitContent, "Commit content should be 'QmContent'.");
        Assert.equal(commit.value, 8, "Commit value should be 8.");
        Assert.equal(commit.ownerTotalValue, 8, "Commit owner's totalValue should be 8.");
        Assert.equal(commit.totalValue, 8, "Commit totalValue should be 8.");
        Assert.equal(commit.height, 1, "Commit height should be 1.");
        Assert.equal(commit.parentHash, bytes32(0), "Commit parentHash should be nussin.");
        // Submission
        bytes32 submissionHash = keccak256(abi.encodePacked(address(this), commitHash, uint256(0)));
        Assert.equal(data.commitToSubmissions[commitHash][0], submissionHash, "Commit hash should be linked to submission hash.");
        Assert.equal(roundZero.info.submissions[0], submissionHash, "Submission should be in round's submissions array.");
        Assert.isTrue(roundZero.hasSubmitted[msg.sender], "hasSubmitted flag should be true for sender.");
        Assert.equal(roundZero.info.submitterCount, 1, "Round should have 1 submitter.");

        // commit state clearing
        delete info.token;
        delete data.whitelist[msg.sender];
        delete data.totalBalance;
        delete data.commitClaims[commitHash];
        delete data.commits[commitHash];
        delete data.commitHashes[contentHash];
        delete data.initialCommits;
        delete data.groups[commit.groupHash].hasMember[msg.sender];
        delete data.groups[commit.groupHash];
        delete transferFromHappened;
        delete transferAmount;
        // tournament state clearing
        delete roundZero.hasSubmitted[msg.sender];
        delete data.tournaments[address(this)].entryFeePaid[msg.sender];
        delete data.tournaments[address(this)];
        delete data.commitToSubmissions[commitHash];
        delete data.commits[commitHash];
        delete data.submissions[submissionHash];
    }

    function testGetAvailableRewardForUserNotWithdrawn() public
    {
        // sender can use matryx
        data.whitelist[msg.sender] = true;
        // commit
        string memory content = "QmContent";
        bytes32 commitHash = keccak256("commit");
        bytes32 groupHash = keccak256("group");
        LibCommit.Commit storage commit = data.commits[commitHash];
        commit.owner = msg.sender;
        commit.timestamp = now - 1;
        commit.groupHash = groupHash;
        commit.commitHash = commitHash;
        commit.content = content;
        commit.value = 4;
        commit.ownerTotalValue = 4;
        commit.totalValue = 4;
        commit.height = 1;
        // child commit
        bytes32 childHash = keccak256("child");
        string memory childContent = "QmChildContent";
        LibCommit.Commit storage child = data.commits[childHash];
        child.owner = address(uint256(msg.sender)+1);
        child.timestamp = now;
        child.groupHash = groupHash;
        child.commitHash = childHash;
        child.content = childContent;
        child.value = 6;
        child.ownerTotalValue = 6;
        child.totalValue = 10;
        child.height = 2;
        child.parentHash = commitHash;
        // balance of commit is 100
        data.commitBalance[childHash] = 100;

        uint256 availableReward = LibCommit.getAvailableRewardForUser(address(this), msg.sender, data, childHash, msg.sender);
        Assert.equal(availableReward, 40, "Available reward incorrect.");

        delete data.whitelist[msg.sender];
        delete data.commits[commitHash];
        delete data.commitBalance[commitHash];
        delete data.commits[childHash];
    }

    function testGetAvailableRewardForUserAlreadyWithdrawn() public
    {
        // sender can use matryx
        data.whitelist[msg.sender] = true;
        // commit
        string memory content = "QmContent";
        bytes32 commitHash = keccak256("commit");
        bytes32 groupHash = keccak256("group");
        LibCommit.Commit storage commit = data.commits[commitHash];
        commit.owner = msg.sender;
        commit.timestamp = now - 1;
        commit.groupHash = groupHash;
        commit.commitHash = commitHash;
        commit.content = content;
        commit.value = 3;
        commit.ownerTotalValue = 3;
        commit.totalValue = 3;
        commit.height = 1;
        // child commit
        bytes32 childHash = keccak256("child");
        string memory childContent = "QmChildContent";
        LibCommit.Commit storage child = data.commits[childHash];
        child.owner = address(uint256(msg.sender)+1);
        child.timestamp = now;
        child.groupHash = groupHash;
        child.commitHash = childHash;
        child.content = childContent;
        child.value = 7;
        child.ownerTotalValue = 7;
        child.totalValue = 10;
        child.height = 2;
        child.parentHash = commitHash;
        // balance of commit is 100
        data.commitBalance[childHash] = 100;
        // already withdrew some
        data.commitWithdrawalStats[childHash].amountWithdrawn[msg.sender] = 5;

        uint256 availableReward = LibCommit.getAvailableRewardForUser(address(this), msg.sender, data, childHash, msg.sender);
        Assert.equal(availableReward, 25, "Available reward incorrect.");

        delete data.whitelist[msg.sender];
        delete data.commits[commitHash];
        delete data.commitBalance[childHash];
        delete data.commitWithdrawalStats[commitHash].amountWithdrawn[msg.sender];
        delete data.commits[childHash];
    }

    function testWithdrawAvailableReward() public
    {
        // set token
        info.token = address(this);
        // sender can use matryx
        data.whitelist[msg.sender] = true;
        // set total balance
        data.totalBalance = 100;
        // commit
        string memory content = "QmContent";
        bytes32 commitHash = keccak256("commit");
        bytes32 groupHash = keccak256("group");
        LibCommit.Commit storage commit = data.commits[commitHash];
        commit.owner = msg.sender;
        commit.timestamp = now - 1;
        commit.groupHash = groupHash;
        commit.commitHash = commitHash;
        commit.content = content;
        commit.value = 9;
        commit.ownerTotalValue = 9;
        commit.totalValue = 9;
        commit.height = 1;
        // child commit
        bytes32 childHash = keccak256("child");
        string memory childContent = "QmChildContent";
        LibCommit.Commit storage child = data.commits[childHash];
        child.owner = address(uint256(msg.sender)+1);
        child.timestamp = now;
        child.groupHash = groupHash;
        child.commitHash = childHash;
        child.content = childContent;
        child.value = 1;
        child.ownerTotalValue = 1;
        child.totalValue = 10;
        child.height = 2;
        child.parentHash = commitHash;
        // balance of commit is 100
        data.commitBalance[childHash] = 100;
        // already withdrew some
        data.commitWithdrawalStats[childHash].amountWithdrawn[msg.sender] = 5;

        LibCommit.withdrawAvailableReward(address(this), msg.sender, info, data, childHash);

        Assert.isTrue(transferHappened, "Token transfer should have happened.");
        Assert.equal(transferAmount, 85, "Transfer value incorrect.");

        delete info.token;
        delete data.whitelist[msg.sender];
        delete data.totalBalance;
        delete data.commits[commitHash];
        delete data.commitBalance[childHash];
        delete data.commitWithdrawalStats[commitHash].amountWithdrawn[msg.sender];
        delete data.commits[childHash];
        delete transferHappened;
        delete transferAmount;
    }
}