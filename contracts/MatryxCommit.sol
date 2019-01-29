pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./MatryxPlatform.sol";

contract MatryxCommit {
    struct Info {
        uint256 version;
        address system;
    }

    Info info;

    constructor(uint256 _version, address _system) public {
        info.version = _version;
        info.system = _system;
    }

    /// @dev
    /// Gets the address of the current version of Platform and forwards the
    /// received calldata to this address. Injects msg.sender at the front so
    /// Platform and libraries can know calling address
    function () external {
        assembly {
            let ptr := mload(0x40)
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let platform := 0x4d6174727978506c6174666f726d000000000000000000000000000000000000
            let version := sload(info_slot)
            let system := sload(add(info_slot, 1))

            // prepare for lookup platform from MSC
            mstore(ptr, mul(0xc53cfd9a, offset))                                // getContract(uint256,bytes32)
            mstore(add(ptr, 0x04), version)                                     // arg 0 - version of this forwarder
            mstore(add(ptr, 0x24), platform)                                    // arg 1 - 'MatryxPlatform'

            // call getContract to get MatryxPlatform from MSC
            let res := call(gas, system, 0, ptr, 0x44, 0, 0x20)                 // call MatryxSystem.getContract
            if iszero(res) { revert(0, 0) }                                     // safety check
            platform := mload(0)                                                // load platform address

            // forward method to MatryxPlatform, injecting msg.sender
            calldatacopy(ptr, 0, 0x04)                                          // copy signature
            mstore(add(ptr, 0x04), caller)                                      // inject msg.sender
            mstore(add(ptr, 0x24), version)                                     // inject version
            calldatacopy(add(ptr, 0x44), 0x04, sub(calldatasize, 0x04))         // copy calldata for forwarding
            res := call(gas, platform, 0, ptr, add(calldatasize, 0x40), 0, 0)   // forward method to MatryxPlatform
            if iszero(res) { revert(0, 0) }                                     // safety check

            // forward returndata to caller
            returndatacopy(ptr, 0, returndatasize)                              // copy returndata into ptr
            return(ptr, returndatasize)                                         // return returndata from forwarded call
        }
    }
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
    // function submitToTournament(bytes32 commitHash, address tournamentAddress, LibSubmission.SubmissionDetails calldata submissionDetails) external; //view returns(LibSubmission.SubmissionDetails memory);
}

library LibCommit {
    using SafeMath for uint256;

    struct CommitData {
        mapping(bytes32=>Commit) commits;                                      // commit hash to commit struct mapping
        bytes32[] initialCommits;                                              // all root level commits (no parent)
        mapping(bytes32=>Group) groups;                                        // group mask hash to group struct mapping
        bytes32[] allGroups;                                                   // array of all group(name) hashes. length is new group number
        mapping(bytes32=>bytes32) commitHashes;                                // top level directory hash to commit hash mapping
        mapping(bytes32=>uint256) commitBalances;
        mapping(bytes32=>uint256) commitBalanceIndex;
        uint256[] nonZeroBalances;
    }

    event JoinGroupRequest(string group, address user);                        // Fired when someone requests to join a group
    event Committed(bytes32 commitHash, bytes32[2] contentHash);               // Fired when a new commit is created

    struct Commit {
        address creator;
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
    /// @param data        All commit data on the Platform
    /// @param commitHash  Commit hash to get
    function getCommit(address self, address sender, LibCommit.CommitData storage data, bytes32 commitHash) public view returns (Commit memory commit) {
        return data.commits[commitHash];
    }

    /// @dev Returns commit data for content hash
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param data         All commit data on the Platform
    /// @param contentHash  Content hash commit was created from
    function getCommitByContentHash(address self, address sender, LibCommit.CommitData storage data, bytes32[2] memory contentHash) public view returns (Commit memory commit) {
        bytes32 lookupHash = keccak256(abi.encodePacked(contentHash));
        bytes32 commitHash = data.commitHashes[lookupHash];
        return data.commits[commitHash];
    }

    /// @dev Returns all initial commits
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    All commit data on the Platform
    function getInitialCommits(address self, address sender, LibCommit.CommitData storage data) public view returns (bytes32[] memory) {
        return data.initialCommits;
    }
    
    /// @dev Returns all group hashes
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    All commit data on the Platform
    function getAllGroups(address self, address sender, LibCommit.CommitData storage data) public view returns (bytes32[] memory) {
        return data.allGroups;
    }

    /// @dev Returns group name for hash
    /// @param self       MatryxCommit address
    /// @param sender     msg.sender to the Platform
    /// @param data       All commit data on the Platform
    /// @param groupHash  Hash of group name
    function getGroupName(address self, address sender, LibCommit.CommitData storage data, bytes32 groupHash) public view returns (string memory) {
        return data.groups[groupHash].name;    
    }

    /// @dev Returns all group members
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    All commit data on the Platform
    /// @param group   Group name
    function getGroupMembers(address self, address sender, LibCommit.CommitData storage data, string memory group) public view returns (address[] memory) {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        require(data.groups[groupHash].exists);
        return data.groups[groupHash].members;
    }

    /// @dev Creates a new group
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    All commit data on the Platform
    /// @param group   Name of the group to create
    function createGroup(address self, address sender, LibCommit.CommitData storage data, string memory group) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        require(!data.groups[groupHash].exists, "Group already exists");

        data.groups[groupHash].exists = true;
        data.groups[groupHash].name = group;
        data.groups[groupHash].hasMember[sender] = true;
        data.groups[groupHash].members.push(sender);
        data.allGroups.push(groupHash);
    }

    /// @dev Request to join a group
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param group   Name of the group to request access to
    function requestToJoinGroup(address self, address sender, string memory group) public {
        emit JoinGroupRequest(group, sender);
    }

    /// @dev Adds a user to a group
    /// @param self    MatryxCommit address
    /// @param sender  msg.sender to the Platform
    /// @param data    All commit data on the Platform
    /// @param group   Name of the group
    /// @param member  Member to add to the group
    function addGroupMember(address self, address sender, LibCommit.CommitData storage data, string memory group, address member) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        require(data.groups[groupHash].exists);
        require(data.groups[groupHash].hasMember[sender]);
        require(!data.groups[groupHash].hasMember[member]);

        data.groups[groupHash].hasMember[member] = true;
        data.groups[groupHash].members.push(member);
    }

    /// @dev Creates a new root commit
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param data         All commit data on the Platform
    /// @param contentHash  Hash of the commits content
    /// @param value        Author-determined value of the commit
    /// @param group        Name of the group working on this branch
    function initialCommit(address self, address sender, LibCommit.CommitData storage data, bytes32[2] memory contentHash, uint256 value, string memory group) public {
        // Create the commit!
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        createCommit(sender, data, contentHash, value, bytes32(0), groupHash);
    }

    /// @dev Creates a new commit off of a parent
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param data         All commit data on the Platform
    /// @param contentHash  Hash of the commits content
    /// @param value        Author-determined value of the commit
    /// @param parentHash   Parent commit hash
    function commit(address self, address sender, LibCommit.CommitData storage data, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash) public {
        Commit storage parent = data.commits[parentHash];
        require(data.groups[parent.groupHash].hasMember[sender], "Must be in the parent commit's group to commit");
    
        // Create the commit!
        createCommit(sender, data, contentHash, value, parentHash, parent.groupHash);
    }

    /// @dev Forks off of an existing commit and creates a new commit, sends MTX to all previous commit creators
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param info         Info struct on the Platform
    /// @param data         All commit data on the Platform
    /// @param contentHash  Hash of the commits content
    /// @param value        Author-determined value of the commit
    /// @param parentHash   Parent commit hash
    /// @param group        Name of the group working on this branch
    function fork(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage platformData, LibCommit.CommitData storage data, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash, string memory group) public {
        // Buy the subtree of the forked commit and distribute to ancestors
        allocateRoyalties(sender, info.token, platformData, data, parentHash);

        // Create the commit!
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        createCommit(sender, data, contentHash, value, parentHash, groupHash);
    }

    /// @dev Creates an initial commit and submits it to a Tournament
    /// @param self         MatryxCommit address
    /// @param sender       msg.sender to the Platform
    /// @param data         All commit data on the Platform
    /// @param tAddress     Address of Tournament to submit to
    /// @param title        Address of Tournament to submit to
    /// @param descHash     IPFS hash of description of the submission
    /// @param contentHash  Hash of the commits content
    /// @param value        Author-determined value of the commit
    /// @param group        Name of the group for the commit
    function commitForTournament(address self, address sender, LibCommit.CommitData storage data, address tAddress, bytes32[3] memory title, bytes32[2] memory descHash, bytes32[2] memory contentHash, uint256 value, string memory group) public {
        bytes32 groupHash = keccak256(abi.encode(group));

        if (!data.groups[groupHash].exists) {
            createGroup(self, sender, data, group);
        }

        bytes32 commitHash = createCommit(sender, data, contentHash, value, bytes32(0), groupHash);
        LibSubmission.SubmissionDetails memory submissionDetails;
        submissionDetails.title = title;
        submissionDetails.descHash = descHash;
        submissionDetails.commitHash = commitHash;

        IMatryxTournament(tAddress).createSubmission(submissionDetails);
    }
    
    /// @dev Initializes a new commit
    /// @param creator      Creator of the commit
    /// @param data         All commit data on the Platform
    /// @param contentHash  Hash of the commits content
    /// @param value        Author-determined value of the commit
    /// @param parentHash   Parent commit hash
    /// @param groupHash    Hash of the name of the group working on this branch
    function createCommit(address creator, LibCommit.CommitData storage data, bytes32[2] memory contentHash, uint256 value, bytes32 parentHash, bytes32 groupHash) internal returns (bytes32) {
        require(data.groups[groupHash].hasMember[creator], "Must be a part of the group");

        bytes32 commitHash = keccak256(abi.encodePacked(parentHash, contentHash));
        bytes32 lookupHash = keccak256(abi.encodePacked(contentHash));

        require(data.commitHashes[lookupHash] == bytes32(0), "A commit has already been created using this content");
        data.commitHashes[lookupHash] = commitHash;

        data.commits[commitHash].creator = creator;
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

    /// @dev Allocates MTX to all ancestor commit creators
    /// @param sender        Address to withdraw funds from
    /// @param token         Token address
    /// @param platformData  MatryxPlatform data
    /// @param data          Collaboration data
    /// @param commitHash    Commit hash to begin distributing funds back from
    function allocateRoyalties(address sender, address token, MatryxPlatform.Data storage platformData, LibCommit.CommitData storage data, bytes32 commitHash) internal {
        Commit storage theCommit = data.commits[commitHash];

        require(IToken(token).transferFrom(sender, address(this), theCommit.totalValue));
        platformData.totalBalance = platformData.totalBalance.add(theCommit.totalValue);
        
        for (uint256 i = theCommit.height; i > 0; i--) {
            platformData.balanceOf[theCommit.creator] = platformData.balanceOf[theCommit.creator] + theCommit.value;
            require(platformData.balanceOf[theCommit.creator] >= theCommit.value);
            theCommit = data.commits[theCommit.parentHash];
        }
    }
}
