pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./MatryxPlatform.sol";
import "./MatryxForwarder.sol";
import "./MatryxTournament.sol";

contract MatryxCommit is MatryxForwarder {
    constructor (uint256 _version, address _system) MatryxForwarder(_version, _system) public {}
}

interface IMatryxCommit {
    function getCommit(bytes32 commitHash) external view returns (LibCommit.Commit memory commit);
    function getBalance(bytes32 commitHash) external view returns (uint256);
    function getCommitByContent(string calldata content) external view returns (LibCommit.Commit memory commit);
    function getInitialCommits() external view returns (bytes32[] memory);
    function getGroupMembers(bytes32 commitHash) external view returns (address[] memory);
    function getSubmissionsForCommit(bytes32 commitHash) external view returns (bytes32[] memory);

    function addGroupMember(bytes32 commitHash, address member) external;
    function addGroupMembers(bytes32 commitHash, address[] calldata members) external;
    function claimCommit(bytes32 commitHash) external;
    function createCommit(bytes32 parentHash, bool isFork, bytes32 salt, string calldata content, uint256 value) external;
    function createSubmission(address tAddress, string calldata content, bytes32 parentHash, bool isFork, bytes32 salt, string calldata commitContent, uint256 value) external;
    function getAvailableRewardForUser(bytes32 commitHash, address user) external view returns (uint256);
    function withdrawAvailableReward(bytes32 commitHash) external;
}

library LibCommit {
    using SafeMath for uint256;

    event GroupMemberAdded(bytes32 commitHash, address user);
    event CommitClaimed(bytes32 commitHash);
    event CommitCreated(bytes32 parentHash, bytes32 commitHash, address creator, bool isFork);

    struct Commit {
        address owner;
        uint256 timestamp;
        bytes32 groupHash;
        bytes32 commitHash;
        string content;
        uint256 value;
        uint256 ownerTotalValue;
        uint256 totalValue;
        uint256 height;
        bytes32 parentHash;
        bytes32[] children;
    }

    struct CommitWithdrawalStats {
        uint256 totalWithdrawn;
        mapping(address=>uint256) amountWithdrawn;
    }

    struct Group {
        address[] members;
        mapping(address=>bool) hasMember;
    }

    /// @dev Returns commit data for the given hash
    /// @param data        Platform data struct
    /// @param commitHash  Hash of the commit to return
    function getCommit(address, address, MatryxPlatform.Data storage data, bytes32 commitHash) public view returns (Commit memory commit) {
        return data.commits[commitHash];
    }

    /// @dev Returns commit data for the given hash
    /// @param data        Platform data struct
    /// @param commitHash  Commit hash
    function getBalance(address, address, MatryxPlatform.Data storage data, bytes32 commitHash) public view returns (uint256) {
        return data.commitBalance[commitHash];
    }

    /// @dev Returns commit data for the given content hash
    /// @param data         Platform data struct
    /// @param content  Content hash commit was created from
    function getCommitByContent(address, address, MatryxPlatform.Data storage data, string memory content) public view returns (Commit memory commit) {
        bytes32 lookupHash = keccak256(abi.encodePacked(content));
        bytes32 commitHash = data.commitHashes[lookupHash];
        return data.commits[commitHash];
    }

    /// @dev Returns all initial commits
    /// @param data    Platform data struct
    function getInitialCommits(address, address, MatryxPlatform.Data storage data) public view returns (bytes32[] memory) {
        return data.initialCommits;
    }

    /// @dev Returns all group members
    /// @param data        Platform data struct
    /// @param commitHash  Commit from line of work
    function getGroupMembers(address, address, MatryxPlatform.Data storage data, bytes32 commitHash) public view returns (address[] memory) {
        bytes32 groupHash = data.commits[commitHash].groupHash;
        return data.groups[groupHash].members;
    }

    /// @dev Returns Round addresses the commit has been submitted to
    /// @param data        Platform data struct
    /// @param commitHash  Hash of the commit to return the rounds of
    function getSubmissionsForCommit(address, address, MatryxPlatform.Data storage data, bytes32 commitHash) public view returns (bytes32[] memory) {
        return data.commitToSubmissions[commitHash];
    }

    /// @dev Returns true if the user is allowed to use Matryx
    function _canUseMatryx(MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address user) internal returns (bool) {
        if (data.blacklist[user]) return false;
        if (data.whitelist[user]) return true;

        if (IToken(info.token).balanceOf(user) > 0) {
            data.whitelist[user] = true;
            return true;
        }

        return false;
    }

    /// @dev Creates a new group
    /// @param data        Platform data struct
    /// @param commitHash  Commit that group is made for
    /// @param user        First user in the group
    function _createGroup(MatryxPlatform.Data storage data, bytes32 commitHash, address user) internal returns (bytes32) {
        bytes32 groupHash = keccak256(abi.encodePacked(commitHash));
        data.groups[groupHash].hasMember[user] = true;
        data.groups[groupHash].members.push(user);
        return groupHash;
    }

    /// @dev Adds a user to a group
    /// @param sender      msg.sender to the Platform
    /// @param data        Platform data struct
    /// @param commitHash  Commit from line of work
    /// @param user        Member to add to the group
    function addGroupMember(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 commitHash, address user) public {
        require(_canUseMatryx(info, data, sender), "Must be allowed to use Matryx");
        require(data.commits[commitHash].owner != address(0), "Invalid commit");

        bytes32 groupHash = data.commits[commitHash].groupHash;
        require(data.groups[groupHash].hasMember[sender], "Only group members can add a new member");
        require(!data.groups[groupHash].hasMember[user], "User is already a group member");

        data.groups[groupHash].hasMember[user] = true;
        data.groups[groupHash].members.push(user);

        emit GroupMemberAdded(commitHash, user);
    }

    /// @dev Adds multiple users to a group
    /// @param sender      msg.sender to the Platform
    /// @param data        Platform data struct
    /// @param commitHash  Commit from line of work
    /// @param users       Members to add to the group
    function addGroupMembers(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 commitHash, address[] memory users) public {
        require(_canUseMatryx(info, data, sender), "Must be allowed to use Matryx");
        require(data.commits[commitHash].owner != address(0), "Invalid commit");

        bytes32 groupHash = data.commits[commitHash].groupHash;
        require(data.groups[groupHash].hasMember[sender], "Only group members can add a new member");

        for(uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (data.groups[groupHash].hasMember[user]) continue;

            data.groups[groupHash].hasMember[user] = true;
            data.groups[groupHash].members.push(user);

            emit GroupMemberAdded(commitHash, user);
        }
    }

    // commit.claimCommit(web3.utils.keccak(sender, salt, ipfsHash))
    /// @dev Claims a hash for future use as a commit
    /// @param sender      msg.sender to the Platform
    /// @param data        Platform data struct
    /// @param commitHash  Hash of (sender + salt + content)
    function claimCommit(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 commitHash) public {
        require(_canUseMatryx(info, data, sender), "Must be allowed to use Matryx");
        require(data.commitClaims[commitHash] == uint256(0), "Commit hash already claimed");

        data.commitClaims[commitHash] = now;
        emit CommitClaimed(commitHash);
    }

    /// @dev Reveals the content hash and salt used in the claiming hash and creates the commit
    /// @param sender       msg.sender to the Platform
    /// @param info         Platform info struct
    /// @param data         Platform data struct
    /// @param parentHash   Parent commit hash
    /// @param isFork       If parent commit is being forked
    /// @param salt         Salt that was used in claiming hash
    /// @param content      Content hash
    /// @param value        Commit value
    function createCommit(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 parentHash, bool isFork, bytes32 salt, string memory content, uint256 value) public {
        require(_canUseMatryx(info, data, sender), "Must be allowed to use Matryx");
        bytes32 commitHash = keccak256(abi.encodePacked(sender, salt, content));

        uint256 claimTime = data.commitClaims[commitHash];
        require(claimTime != uint256(0), "Commit must be claimed first");

        _createCommit(sender, info, data, parentHash, commitHash, isFork, content, value);
    }

    /// @dev Creates a commit and submits it to a Tournament
    /// @param sender       msg.sender to the Platform
    /// @param info         Platform info struct
    /// @param data         Platform data struct
    /// @param tAddress     Tournament address to submit to
    /// @param content      Submission title and description IPFS hash
    /// @param parentHash   Parent commit hash
    /// @param isFork       If fork
    /// @param salt         Salt that was used in claiming hash
    /// @param commitContent  Commit content IPFS hash
    /// @param value        Author-determined commit value
    function createSubmission(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address tAddress, string memory content, bytes32 parentHash, bool isFork, bytes32 salt, string memory commitContent, uint256 value) public {
        require(_canUseMatryx(info, data, sender), "Must be allowed to use Matryx");
        bytes32 commitHash = keccak256(abi.encodePacked(sender, salt, commitContent));

        uint256 claimTime = data.commitClaims[commitHash];
        require(claimTime != uint256(0), "Commit must be claimed first");

        _createCommit(sender, info, data, parentHash, commitHash, isFork, commitContent, value);
        LibTournament.createSubmission(tAddress, sender, info, data, content, commitHash);
    }

    /// @dev Initializes a new commit
    /// @param owner        Commit owner
    /// @param data         Platform data struct
    /// @param parentHash   Parent commit hash
    /// @param commitHash   Commit hash
    /// @param isFork       If commit is fork of parent
    /// @param content  Commit content IPFS hash
    /// @param value        Author-determined commit value
    function _createCommit(address owner, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 parentHash, bytes32 commitHash, bool isFork, string memory content, uint256 value) internal {
        require(value > 0, "Cannot create a zero-value commit");
        require(data.commits[commitHash].owner == address(0), "Commit already exists");

        bytes32 lookupHash = keccak256(abi.encodePacked(content));
        require(data.commitHashes[lookupHash] == bytes32(0), "Commit already created from content");

        // if fork, increase balance of parent
        if (isFork) {
            uint256 totalValue = data.commits[parentHash].totalValue;
            data.totalBalance = data.totalBalance.add(totalValue);
            data.commitBalance[parentHash] = data.commitBalance[parentHash].add(totalValue);
            require(IToken(info.token).transferFrom(owner, address(this), totalValue));
        }

        bytes32 groupHash;
        if (isFork || parentHash == bytes32(0)) {
            // if fork or new commit, create a new group
            groupHash = _createGroup(data, commitHash, owner);
        } else {
            // otherwise use parent's group
            groupHash = data.commits[parentHash].groupHash;
            require(data.groups[groupHash].hasMember[owner], "Must be a part of the group");
        }

        // calculate owner total value
        uint256 ownerTotalValue = value;
        if (parentHash != bytes32(0)) {
            bytes32 latest = _getLatestCommitForUser(data, parentHash, owner);

            if (latest != bytes32(0)) {
                ownerTotalValue = ownerTotalValue.add(data.commits[latest].ownerTotalValue);
            }
        }

        // create commit
        data.commits[commitHash].owner = owner;
        data.commits[commitHash].timestamp = now;
        data.commits[commitHash].groupHash = groupHash;
        data.commits[commitHash].commitHash = commitHash;
        data.commits[commitHash].content = content;
        data.commits[commitHash].value = value;
        data.commits[commitHash].ownerTotalValue = ownerTotalValue;
        data.commits[commitHash].totalValue = data.commits[parentHash].totalValue.add(value);
        data.commits[commitHash].height = data.commits[parentHash].height + 1;
        data.commits[commitHash].parentHash = parentHash;

        data.commitHashes[lookupHash] = commitHash;

        if (parentHash == bytes32(0)) {
            data.initialCommits.push(commitHash);
        } else {
            data.commits[parentHash].children.push(commitHash);
        }

        emit CommitCreated(parentHash, commitHash, owner, isFork);
    }

    /// @dev Returns the available reward for a user for a given commit
    /// @param data        Platform data struct
    /// @param commitHash  Commit hash to look up the available reward
    /// @param user        User address
    /// @return            Amount of MTX the user can withdraw from the given commit
    function getAvailableRewardForUser(address, address sender, MatryxPlatform.Data storage data, bytes32 commitHash, address user) public view returns (uint256) {
        bytes32 latestUserCommit = _getLatestCommitForUser(data, commitHash, user);
        if (latestUserCommit == bytes32(0)) return 0;

        CommitWithdrawalStats storage stats = data.commitWithdrawalStats[commitHash];

        uint256 userValue = data.commits[latestUserCommit].ownerTotalValue;
        uint256 totalValue = data.commits[commitHash].totalValue;
        uint256 balance = data.commitBalance[commitHash];
        uint256 totalBalance = balance.add(stats.totalWithdrawn);

        uint256 userShare = totalBalance.mul(userValue).div(totalValue).sub(stats.amountWithdrawn[user]);

        return userShare;
    }

    /// @dev Withdraws the caller's available reward for a given commit
    /// @param sender      msg.sender to the Platform
    /// @param info        Platform info struct
    /// @param data        Platform data struct
    /// @param commitHash  Commit hash to look up the available reward
    function withdrawAvailableReward(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 commitHash) public {
        require(_canUseMatryx(info, data, sender), "Must be allowed to use Matryx");
        require(data.commits[commitHash].owner != address(0), "Commit does not exist");
        uint256 userShare = getAvailableRewardForUser(sender, sender, data, commitHash, sender);
        require(userShare > 0, "No reward available");

        CommitWithdrawalStats storage stats = data.commitWithdrawalStats[commitHash];

        data.totalBalance = data.totalBalance.sub(userShare);
        data.commitBalance[commitHash] = data.commitBalance[commitHash].sub(userShare);
        stats.totalWithdrawn = stats.totalWithdrawn.add(userShare);
        stats.amountWithdrawn[sender] = stats.amountWithdrawn[sender].add(userShare);

        require(IToken(info.token).transfer(sender, userShare), "Transfer failed");
    }

    /// @dev Returns the hash of the user's latest commit in the chain of ancestors of commitHash
    /// @param data        Platform data struct
    /// @param commitHash  Commit hash to look up the available reward
    /// @param user        User address
    /// @return            User's latest commit hash
    function _getLatestCommitForUser(MatryxPlatform.Data storage data, bytes32 commitHash, address user) internal view returns (bytes32) {
        Commit storage c = data.commits[commitHash];

        // traverse up until root commit
        while (true) {
            if (c.owner == user) return c.commitHash;
            if (c.parentHash == bytes32(0)) return bytes32(0);
            c = data.commits[c.parentHash];
        }
    }
}
