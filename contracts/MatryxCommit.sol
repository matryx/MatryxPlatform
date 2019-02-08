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
    function getCommitByContentHash(bytes32[2] calldata contentHash) external view returns (LibCommit.Commit memory commit);
    function getInitialCommits() external view returns (bytes32[] memory);
    function getAllGroups() external view returns (bytes32[] memory);
    function getGroupName(bytes32 groupHash) external view returns (string memory);
    function getGroupMembers(string calldata group) external view returns (address[] memory);
    function getRoundsSubmittedTo(bytes32 commitHash) external view returns (address[] memory);

    function createGroup(string calldata group) external returns (address);
    function requestToJoinGroup(string calldata group) external;
    function addGroupMember(string calldata group, address newUser) external;
    function claimCommit(bytes32 commitHash) external;
    function revealCommit(bytes32 salt, bytes32[2] calldata contentHash, uint256 value, bytes32 parentHash, string calldata group) external;
    function commit(bytes32[2] calldata contentHash, uint256 value, bytes32 parentHash, string calldata group) external;
    function fork(bytes32[2] calldata contentHash, uint256 value, bytes32 parentHash, string calldata group) external;
    function submitToTournament(address tAddress, bytes32[3] calldata title, bytes32[2] calldata descHash, bytes32[2] calldata contentHash, uint256 value, bytes32 parentHash, string calldata group) external;
    function getAvailableRewardForUser(bytes32 commitHash, address user) external view returns (uint256);
    function withdrawAvailableReward(bytes32 commitHash) external;
}

library LibCommit {
    using SafeMath for uint256;

    event GroupMemberRequested(string group, address user);                           // Someone requests to join a group
    event GroupMemberAdded(string group, address user);                               // Someone is added to a group
    event CommitCreated(bytes32 parentHash, bytes32 commitHash, address creator);     // A new commit is created
    event ForkCreated(bytes32 parentHash, bytes32 commitHash, address creator);       // A commit is forked off of parentHash
    event BalanceIncreased(bytes32 commitHash);                                       // A commit balance has increased
    event CommitClaimed(bytes32 commitHash);                                          // A commit has been claimed
    event CommitDeleted(bytes32 commitHash);                                          // A commit is deleted

    struct Commit {
        address owner;
        uint256 timestamp;
        bytes32 groupHash;
        bytes32 commitHash;
        bytes32[2] contentHash;
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
        bool exists;
        string name;
        address[] members;
        mapping(address=>bool) hasMember;
    }

    /// @dev Returns commit data for the given hash
    /// @param self        MatryxCommit address
    /// @param sender      msg.sender to the Platform
    /// @param data        Platform data struct
    /// @param commitHash  Hash of the commit to return
    function getCommit(address self, address sender, MatryxPlatform.Data storage data, bytes32 commitHash) public view returns (Commit memory commit) {
        return data.commits[commitHash];
    }

    /// @dev Returns commit data for the given content hash
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param data         Platform data struct
    /// @param contentHash  Content hash commit was created from
    function getCommitByContentHash(address self, address sender, MatryxPlatform.Data storage data, bytes32[2] memory contentHash) public view returns (Commit memory commit) {
        bytes32 lookupHash = keccak256(abi.encodePacked(contentHash));
        bytes32 commitHash = data.commitHashes[lookupHash];
        return data.commits[commitHash];
    }

    /// @dev Returns all initial commits
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    Platform data struct
    function getInitialCommits(address self, address sender, MatryxPlatform.Data storage data) public view returns (bytes32[] memory) {
        return data.initialCommits;
    }

    /// @dev Returns all group hashes
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    Platform data struct
    function getAllGroups(address self, address sender, MatryxPlatform.Data storage data) public view returns (bytes32[] memory) {
        return data.allGroups;
    }

    /// @dev Returns group name for given hash
    /// @param self       MatryxCommit address
    /// @param sender     msg.sender to the Platform
    /// @param data       Platform data struct
    /// @param groupHash  Hash of group name
    function getGroupName(address self, address sender, MatryxPlatform.Data storage data, bytes32 groupHash) public view returns (string memory) {
        return data.groups[groupHash].name;
    }

    /// @dev Returns all group members
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    Platform data struct
    /// @param group   Group name
    function getGroupMembers(address self, address sender, MatryxPlatform.Data storage data, string memory group) public view returns (address[] memory) {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        require(data.groups[groupHash].exists);
        return data.groups[groupHash].members;
    }

    /// @dev Returns Round addresses the commit has been submitted to
    /// @param self        MatryxCommit address
    /// @param sender      msg.sender to the Platform
    /// @param data        Platform data struct
    /// @param commitHash  Hash of the commit to return the rounds of
    function getRoundsSubmittedTo(address self, address sender, MatryxPlatform.Data storage data, bytes32 commitHash) public view returns (address[] memory) {
        return data.commitToRounds[commitHash];
    }

    /// @dev Creates a new group
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    Platform data struct
    /// @param group   Name of the group to create
    function createGroup(address self, address sender, MatryxPlatform.Data storage data, string memory group) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        require(!data.groups[groupHash].exists, "Group already exists");
        require(data.users[sender].entered, "Must have entered Matryx");

        data.groups[groupHash].exists = true;
        data.groups[groupHash].name = group;
        data.groups[groupHash].hasMember[sender] = true;
        data.groups[groupHash].members.push(sender);
        data.allGroups.push(groupHash);
    }

    /// @dev Request to join a group
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    Platform data struct
    /// @param group   Name of the group to request access to
    function requestToJoinGroup(address self, address sender, MatryxPlatform.Data storage data, string memory group) public {
        require(data.users[sender].entered, "Must have entered Matryx");
        emit GroupMemberRequested(group, sender);
    }

    /// @dev Adds a user to a group
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    Platform data struct
    /// @param group   Name of the group
    /// @param member  Member to add to the group
    function addGroupMember(address self, address sender, MatryxPlatform.Data storage data, string memory group, address member) public {
        require(data.users[sender].entered, "Must have entered Matryx");
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        require(data.groups[groupHash].exists);
        require(data.groups[groupHash].hasMember[sender]);
        require(!data.groups[groupHash].hasMember[member]);

        data.groups[groupHash].hasMember[member] = true;
        data.groups[groupHash].members.push(member);

        emit GroupMemberAdded(group, member);
    }

    // commit.claimCommit(web3.utils.keccak(sender, salt, ipfsHash))
    /// @dev Claims a hash for future use as a commit
    /// @param self        MatryxCommit address
    /// @param sender      msg.sender to the Platform
    /// @param data        Platform data struct
    /// @param commitHash  Hash of (sender + salt + contentHash)
    function claimCommit(address self, address sender, MatryxPlatform.Data storage data, bytes32 commitHash) public {
        require(data.users[sender].entered, "Must have entered Matryx");
        require(data.commitClaims[commitHash] == uint256(0));
        data.commitClaims[commitHash] = now;
        emit CommitClaimed(commitHash);
    }

    /// @dev Reveals the content hash and salt used in the claiming hash and creates the commit
    /// @param self        MatryxCommit address
    /// @param sender      msg.sender to the Platform
    /// @param data        Platform data struct
    /// @param salt        Salt that was used in claiming hash
    /// @param contentHash Content hash
    /// @param value       Commit value
    /// @param parentHash  Parent commit hashParent commit hash
    function revealCommit(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 salt, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash, string memory group) public {
        require(data.users[sender].entered, "Must have entered Matryx");
        bytes32 commitHash = keccak256(abi.encodePacked(sender, salt, contentHash));

        bytes32 groupHash;
        if (parentHash == bytes32(0)) {
            groupHash = keccak256(abi.encodePacked(group));
            if (!data.groups[groupHash].exists) {
                createGroup(self, sender, data, group);
            }
        } else {
            groupHash = data.commits[parentHash].groupHash;
        }

        uint256 claimTime = data.commitClaims[commitHash];
        require(claimTime != uint256(0));
        
        bytes32 lookupHash = keccak256(abi.encodePacked(contentHash));
        bytes32 priorCommitHash = data.commitHashes[lookupHash];
        LibCommit.Commit storage commit = data.commits[priorCommitHash];

        // check if reveal was frontrun
        if (priorCommitHash != 0 && claimTime < commit.timestamp) {
            data.commitClaims[commitHash] = 0;
            data.users[commit.owner].banned = true;
            data.users[commit.owner].entered = false;
            assembly {
                sstore(add(commit_slot, 12), 0)
            }
            delete data.commits[priorCommitHash];
            emit CommitDeleted(priorCommitHash);
        }

        createCommit(sender, info, data, commitHash, contentHash, value, parentHash, groupHash);
    }

    function commit(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash, string memory group) public {
        require(data.users[sender].entered, "Must have entered Matryx");
        bytes32 commitHash = keccak256(abi.encodePacked(sender, bytes32(0), contentHash));
        claimCommit(self, sender, data, commitHash);
        revealCommit(self, sender, info, data, bytes32(0), contentHash, value, parentHash, group);
    }

    /// @dev Forks off of an existing commit and creates a new commit, sends subtree MTX to forked commit in platform
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param info         Platform info struct
    /// @param data         Platform data struct
    /// @param contentHash  Hash of the commits content
    /// @param value        Author-determined value of the commit
    /// @param parentHash   Parent commit hash
    /// @param group        Name of the group working on this branch
    function fork(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash, string memory group) public {
        require(data.users[sender].entered, "Must have entered Matryx");
        // require(data.commits[parentHash].owner != address(0), "Must fork an existing commit");

        // Create the commit!
        bytes32 commitHash = keccak256(abi.encodePacked(sender, bytes32(0), contentHash));
        claimCommit(self, sender, data, commitHash);
        revealCommit(self, sender, info, data, bytes32(0), contentHash, value, parentHash, group);
    }

    /// @dev Initializes a new commit
    /// @param owner        Commit owner
    /// @param data         Platform data struct
    /// @param contentHash  Commit content IPFS hash
    /// @param value        Author-determined commit value
    /// @param parentHash   Parent commit hash
    /// @param groupHash    Group name hash
    function createCommit(address owner, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 commitHash, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash, bytes32 groupHash) internal {
        require(data.groups[groupHash].hasMember[owner], "Must be a part of the group");
        require(value > 0, "Cannot create a zero-value commit.");
        require(data.commits[commitHash].owner == address(0), "Commit already exists");

        // // if fork, transfer to parent first
        // if (parentHash != bytes32(0) && data.commits[parentHash].groupHash != groupHash) {
        //     uint256 totalValue = data.commits[parentHash].totalValue;
        //     data.totalBalance = data.totalBalance.add(totalValue);
        //     data.commitBalance[parentHash] = data.commitBalance[parentHash].add(totalValue);
        //     require(IToken(info.token).transferFrom(owner, address(this), totalValue));
            
        //     emit BalanceIncreased(parentHash);
        //     emit ForkCreated(parentHash, commitHash, owner);
        // } else {
        //     emit CommitCreated(parentHash, commitHash, owner);
        // }

        uint256 ownerTotalValue = value;

        if (parentHash != bytes32(0)) {
            bytes32 latest = getLatestCommitForUser(data, parentHash, owner);

            if (latest != bytes32(0)) {
                ownerTotalValue = ownerTotalValue.add(data.commits[latest].ownerTotalValue);
            }
        }

        data.commits[commitHash].owner = owner;
        data.commits[commitHash].timestamp = now;
        data.commits[commitHash].groupHash = groupHash;
        data.commits[commitHash].commitHash = commitHash;
        data.commits[commitHash].contentHash = contentHash;
        data.commits[commitHash].value = value;
        data.commits[commitHash].ownerTotalValue = ownerTotalValue;
        data.commits[commitHash].totalValue = data.commits[parentHash].totalValue.add(value);
        data.commits[commitHash].height = data.commits[parentHash].height + 1;
        data.commits[commitHash].parentHash = parentHash;

        bytes32 lookupHash = keccak256(abi.encodePacked(contentHash));
        data.commitHashes[lookupHash] = commitHash;

        if (parentHash == bytes32(0)) {
            data.initialCommits.push(commitHash);
        } else {
            data.commits[parentHash].children.push(commitHash);
        }
    }

    /// @dev Creates a commit and submits it to a Tournament
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param info         Platform info struct
    /// @param data         Platform data struct
    /// @param tAddress     Tournament address to submit to
    /// @param title        Submission title
    /// @param descHash     Submission description IPFS hash
    /// @param contentHash  Commit content IPFS hash
    /// @param value        Author-determined commit value
    /// @param parentHash   Parent commit hash
    /// @param group        Group name for the commit
    function submitToTournament(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address tAddress, bytes32[3] memory title, bytes32[2] memory descHash, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash, string memory group) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));

        if (parentHash != bytes32(0)) {
            require(data.commits[parentHash].groupHash == groupHash);
        }

        if (!data.groups[groupHash].exists) {
            createGroup(self, sender, data, group);
        }

        bytes32 commitHash = keccak256(abi.encodePacked(sender, bytes32(0), contentHash));
        createCommit(sender, info, data, commitHash, contentHash, value, parentHash, groupHash);
        LibTournament.createSubmission(tAddress, sender, data, title, descHash, commitHash);
    }

    /// @dev Returns the available reward for a user for a given commit
    /// @param data        Platform data struct
    /// @param commitHash  Commit hash to look up the available reward
    /// @param user        User address
    /// @return            Amount of MTX the user can withdraw from the given commit
    function getAvailableRewardForUser(address self, address sender, MatryxPlatform.Data storage data, bytes32 commitHash, address user) public returns (uint256) {
        bytes32 latestUserCommit = getLatestCommitForUser(data, commitHash, user);
        if (latestUserCommit == bytes32(0)) return 0;

        CommitWithdrawalStats storage stats = data.commitWithdrawalStats[commitHash];

        uint256 userValue = data.commits[latestUserCommit].ownerTotalValue;
        uint256 totalValue = data.commits[commitHash].totalValue;
        uint256 balance = data.commitBalance[commitHash];
        uint256 totalBalance = balance.add(stats.totalWithdrawn);

        uint256 userShare = totalBalance.mul(userValue).div(totalValue).sub(stats.amountWithdrawn[sender]);

        return userShare;
    }

    /// @dev Withdraws the caller's available reward for a given commit
    /// @param self        MatryxCommit address
    /// @param sender      msg.sender to the Platform
    /// @param data        Platform data struct
    /// @param commitHash  Commit hash to look up the available reward
    function withdrawAvailableReward(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 commitHash) public {
        uint256 userShare = getAvailableRewardForUser(self, sender, data, commitHash, sender);
        require(userShare > 0, "No reward available");

        CommitWithdrawalStats storage stats = data.commitWithdrawalStats[commitHash];

        data.totalBalance = data.totalBalance.sub(userShare);
        data.commitBalance[commitHash] = data.commitBalance[commitHash].sub(userShare);
        stats.totalWithdrawn = stats.totalWithdrawn.add(userShare);
        stats.amountWithdrawn[sender] = stats.amountWithdrawn[sender].add(userShare);
         
        require(IToken(info.token).transfer(sender, userShare), "Transfer failed");
    }

    event NamedEvent(bytes32 commitHash, address user);

    /// @dev Returns the hash of the user's latest commit in the chain of ancestors of commitHash
    /// @param data        Platform data struct
    /// @param commitHash  Commit hash to look up the available reward
    /// @param user        User address
    /// @return            User's latest commit hash
    function getLatestCommitForUser(MatryxPlatform.Data storage data, bytes32 commitHash, address user) internal returns (bytes32) {
        Commit storage commit = data.commits[commitHash];

        emit NamedEvent(commitHash, user);
        
        for (uint256 i = commit.height; i >= 0; i--) {
            if (commit.owner == user) return commit.commitHash;
            commit = data.commits[commit.parentHash];
        }

        return bytes32(0);
    }
}
