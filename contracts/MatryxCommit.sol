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

    function createGroup(string calldata group) external returns (address);
    function requestToJoinGroup(string calldata group) external;
    function addGroupMember(string calldata group, address newUser) external;
    function initialCommit(bytes32[2] calldata contentHash, uint256 value, string calldata group) external;
    function commit(bytes32[2] calldata contentHash, uint256 value, bytes32 parentHash) external;
    function fork(bytes32[2] calldata contentHash, uint256 value, bytes32 parentHash, string calldata group) external;
    function submitToTournament(address tAddress, bytes32[3] calldata title, bytes32[2] calldata descHash, bytes32[2] calldata contentHash, uint256 value, bytes32 parentHash, string calldata group) external;
    function distributeReward(bytes32 commitHash) external;
}

library LibCommit {
    using SafeMath for uint256;

    event JoinGroupRequest(string group, address user);                         // Fired when someone requests to join a group
    event NewGroupMember(string group, address user);                           // Fired when someone is added to a group
    event Committed(bytes32 commitHash, bytes32[2] contentHash);                // Fired when a new commit is created
    event Fork(bytes32 parentHash, bytes32 commitHash, address creator);        // Fired when a commit is forked off of parentHash

    struct Commit {
        address owner;
        bytes32 groupHash;
        bytes32 commitHash;
        bytes32[2] contentHash;
        uint256 value;
        uint256 totalValue;
        uint256 height;
        bytes32 parentHash;
        bytes32[] children;
    }

    struct Group {
        bool exists;
        string name;
        mapping(address=>bool) hasMember;
        address[] members;
    }

    /// @dev Returns commit data for hash
    /// @param self        MatryxCommit address
    /// @param sender      msg.sender to the Platform
    /// @param data        Platform data struct
    /// @param commitHash  Commit hash to get
    function getCommit(address self, address sender, MatryxPlatform.Data storage data, bytes32 commitHash) public view returns (Commit memory commit) {
        return data.commits[commitHash];
    }

    /// @dev Returns commit data for content hash
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

    /// @dev Returns group name for hash
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
    /// @param commitHash  Commit hash to get
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
        require(data.users[sender].exists, "Must have entered Matryx");

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
        require(data.users[sender].exists, "Must have entered Matryx");
        emit JoinGroupRequest(group, sender);
    }

    /// @dev Adds a user to a group
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    Platform data struct
    /// @param group   Name of the group
    /// @param member  Member to add to the group
    function addGroupMember(address self, address sender, MatryxPlatform.Data storage data, string memory group, address member) public {
        require(data.users[sender].exists, "Must have entered Matryx");
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        require(data.groups[groupHash].exists);
        require(data.groups[groupHash].hasMember[sender]);
        require(!data.groups[groupHash].hasMember[member]);

        data.groups[groupHash].hasMember[member] = true;
        data.groups[groupHash].members.push(member);

        emit NewGroupMember(group, member);
    }

    /// @dev Creates a new root commit
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param data         Platform data struct
    /// @param contentHash  Hash of the commits content
    /// @param value        Author-determined value of the commit
    /// @param group        Name of the group working on this branch
    function initialCommit(address self, address sender, MatryxPlatform.Data storage data, bytes32[2] memory contentHash, uint256 value, string memory group) public {
        require(data.users[sender].exists, "Must have entered Matryx");

        bytes32 groupHash = keccak256(abi.encodePacked(group));
        if (!data.groups[groupHash].exists) {
            createGroup(self, sender, data, group);
        }

        // Create the commit!
        createCommit(sender, data, contentHash, value, bytes32(0), groupHash);
    }

    /// @dev Creates a new commit off of a parent
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param data         Platform data struct
    /// @param contentHash  Hash of the commits content
    /// @param value        Author-determined value of the commit
    /// @param parentHash   Parent commit hash
    function commit(address self, address sender, MatryxPlatform.Data storage data, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash) public {
        require(data.users[sender].exists, "Must have entered Matryx");
        Commit storage parent = data.commits[parentHash];
        require(data.groups[parent.groupHash].hasMember[sender], "Must be in the parent commit's group to commit");

        // Create the commit!
        createCommit(sender, data, contentHash, value, parentHash, parent.groupHash);
    }

    /// @dev Forks off of an existing commit and creates a new commit, sends MTX to all previous commit owners
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param info         Platform info struct
    /// @param data         Platform data struct
    /// @param contentHash  Hash of the commits content
    /// @param value        Author-determined value of the commit
    /// @param parentHash   Parent commit hash
    /// @param group        Name of the group working on this branch
    function fork(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash, string memory group) public {
        require(data.users[sender].exists, "Must have entered Matryx");

        bytes32 groupHash = keccak256(abi.encodePacked(group));
        if (!data.groups[groupHash].exists) {
            createGroup(self, sender, data, group);
        }

        // Buy the subtree of the forked commit and distribute to ancestors
        distributeFunds(sender, info.token, data, parentHash, 0);

        // Create the commit!
        bytes32 commitHash = createCommit(sender, data, contentHash, value, parentHash, groupHash);

        emit Fork(parentHash, commitHash, sender);
    }

    /// @dev Creates an initial commit and submits it to a Tournament
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param data         Platform data struct
    /// @param tAddress     Tournament address to submit to
    /// @param title        Submission title
    /// @param descHash     Submission description IPFS hash
    /// @param contentHash  Commit content IPFS hash
    /// @param value        Author-determined commit value
    /// @param parentHash   Parent commit hash
    /// @param group        Group name for the commit
    function submitToTournament(address self, address sender, MatryxPlatform.Data storage data, address tAddress, bytes32[3] memory title, bytes32[2] memory descHash, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash, string memory group) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));

        if (!data.groups[groupHash].exists) {
            createGroup(self, sender, data, group);
        }

        bytes32 commitHash = createCommit(sender, data, contentHash, value, parentHash, groupHash);
        LibTournament.createSubmission(tAddress, sender, data, title, descHash, commitHash);
    }

    /// @dev Initializes a new commit
    /// @param owner        Owner of the commit
    /// @param data         Platform data struct
    /// @param contentHash  Commit content IPFS hash
    /// @param value        Author-determined commit value
    /// @param parentHash   Parent commit hash
    /// @param groupHash    Group name hash
    function createCommit(address owner, MatryxPlatform.Data storage data, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash, bytes32 groupHash) internal returns (bytes32) {
        require(data.groups[groupHash].hasMember[owner], "Must be a part of the group");

        bytes32 commitHash = keccak256(abi.encodePacked(parentHash, contentHash));
        bytes32 lookupHash = keccak256(abi.encodePacked(contentHash));

        require(data.commitHashes[lookupHash] == bytes32(0), "A commit has already been created using this content");
        data.commitHashes[lookupHash] = commitHash;

        data.commits[commitHash].owner = owner;
        data.commits[commitHash].groupHash = groupHash;
        data.commits[commitHash].commitHash = commitHash;
        data.commits[commitHash].contentHash = contentHash;
        data.commits[commitHash].value = value;
        data.commits[commitHash].totalValue = data.commits[parentHash].totalValue.add(value);
        data.commits[commitHash].height = data.commits[parentHash].height + 1;
        data.commits[commitHash].parentHash = parentHash;

        if (parentHash == bytes32(0)) {
            data.initialCommits.push(commitHash);
        } else {
            data.commits[parentHash].children.push(commitHash);
        }

        emit Committed(commitHash, contentHash);
        return commitHash;
    }

    /// @dev Distributes any pending MTX to all commit owners in the chain
    /// @param self        MatryxCommit address
    /// @param sender      msg.sender to the Platform
    /// @param info        Platform info struct
    /// @param data        Platform data struct
    /// @param commitHash  Commit hash
    function distributeReward(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 commitHash) public {
        uint256 reward = data.commitBalance[commitHash];
        require(reward != 0, "No reward to distribute");

        distributeFunds(sender, info.token, data, commitHash, reward);
        data.commitBalance[commitHash] = 0;
    }

    /// @dev Distributes MTX (up to maxDepth) to all commit owners in the chain
    /// @param sender        Address to withdraw funds from if fork
    /// @param token         Token address
    /// @param data          Platform data struct
    /// @param commitHash    Commit hash to begin distributing funds back from
    /// @param bounty        Tournament bounty; 0 if fork
    function distributeFunds(address sender, address token, MatryxPlatform.Data storage data, bytes32 commitHash, uint256 bounty) internal {
        Commit storage theCommit = data.commits[commitHash];

        uint256 depth = theCommit.height;
        uint256 maxDepth = data.commitDistributionDepth;
        uint256 totalValue = theCommit.totalValue;

        // if commit chain longer than maxDepth, only pay last maxDepth
        if (depth >= maxDepth) {
            Commit storage tempCommit = data.commits[commitHash];
            
            for (uint256 i = 0; i < maxDepth; i++) { // at least 200k gas
                tempCommit = data.commits[tempCommit.parentHash];
            }
            depth = maxDepth;
            totalValue = totalValue.sub(tempCommit.totalValue);
        }

        // funds is totalValue if fork, otherwise provided bounty amount
        uint256 funds = bounty;

        if (bounty == 0) { // if fork
            funds = totalValue;
            data.totalBalance = data.totalBalance.add(funds);
            require(IToken(token).transferFrom(sender, address(this), funds));
        }

        for (uint256 i = 0; i < depth; i++) {
            uint256 amount = funds.mul(theCommit.value).div(totalValue);
            data.balanceOf[theCommit.owner] = data.balanceOf[theCommit.owner].add(amount);
            theCommit = data.commits[theCommit.parentHash];
        }
    }
}
