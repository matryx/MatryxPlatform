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
    function getRootCommits() external view returns (bytes32[] memory);
    function getAllGroups() external view returns (bytes32[] memory);
    function createGroup(string calldata group) external returns (address);
    function requestToJoinGroup(string calldata group) external;
    function addUserToGroup(string calldata group, address newUser) external;
    function createCommit(LibCommit.NewCommit calldata newCommit, string calldata group) external;
    function fork(LibCommit.NewCommit calldata newCommit, string calldata group) external;
}

library LibCommit {
    using SafeMath for uint256;

    struct CollaborationData {
        mapping(bytes32=>Commit) commits;                                      // commit hash to commit struct mapping
        bytes32[] rootCommits;                                                 // all root level commits (no parent)
        mapping(bytes32=>Group) groups;                                        // group mask hash to group struct mapping
        bytes32[] allGroups;                                                   // array of all group(name) hashes. length is new group number
        mapping(bytes32=>bytes32) treeToCommit;                                // top level directory hash to commit hash mapping
    }

    event JoinGroupRequest(string group, address user);                        // Fired when someone requests to join a group
    event Committed(bytes32 commitHash, bytes32 _mergeTree);                   // Fired when a new commit is created

    struct Commit {
        address creator;
        bytes32 group;
        bytes32 commitHash;
        bytes32 treeHash;
        uint256 value;
        uint256 totalValue;
        uint256 height;
        bytes32 parent;
        bytes32[] children;
    }

    struct NewCommit {
        bytes32 treeHash;
        uint256 value;
        bytes32 parent;
    }

    struct Group {
        bool exists;
        mapping(address=>bool) containsUser;
        address[] users;
    }

    /// @dev Returns commit data for hash
    /// @param self        Address of contract calling this method: MatryxPlatform
    /// @param sender      msg.sender to the Platform
    /// @param data        All commit data on the Platform
    /// @param commitHash  Commit hash to get
    function getCommit(address self, address sender, LibCommit.CollaborationData storage data, bytes32 commitHash) public view returns (Commit memory commit) {
        return data.commits[commitHash];
    }

    /// @dev Returns commit data for hash
    /// @param self        Address of contract calling this method: MatryxPlatform
    /// @param sender      msg.sender to the Platform
    /// @param data        All commit data on the Platform
    function getRootCommits(address self, address sender, LibCommit.CollaborationData storage data) public view returns (bytes32[] memory) {
        return data.rootCommits;
    }

    /// @dev Returns commit data for hash
    /// @param self        Address of contract calling this method: MatryxPlatform
    /// @param sender      msg.sender to the Platform
    /// @param data        All commit data on the Platform
    function getAllGroups(address self, address sender, LibCommit.CollaborationData storage data) public view returns (bytes32[] memory) {
        return data.allGroups;
    }

    function withdrawBalance(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage platformData) public {
        uint256 amount = platformData.balanceOf[sender];
        platformData.balanceOf[sender] = 0;
        require(IToken(info.token).transfer(sender, amount));
    }

    /// @dev Creates a new group
    /// @param self    Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data    All commit data on the Platform
    /// @param group   Name of the group to create
    function createGroup(address self, address sender, LibCommit.CollaborationData storage data, string memory group) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        require(!data.groups[groupHash].exists, "Group already exists");

        data.groups[groupHash].exists = true;
        data.allGroups.push(groupHash);
        data.groups[groupHash].containsUser[sender] = true;
        data.groups[groupHash].users.push(sender);
    }

    /// @dev Request to join a group
    /// @param self    Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data    All commit data on the Platform
    /// @param group   Name of the group to request access to
    function requestToJoinGroup(address self, address sender, LibCommit.CollaborationData storage data, string memory group) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        emit JoinGroupRequest(group, sender);
    }

    /// @dev Adds a user to a group
    /// @param self     Address of contract calling this method: MatryxPlatform
    /// @param sender   msg.sender to the Platform
    /// @param data     All commit data on the Platform
    /// @param group    Name of the group
    /// @param newUser  User to add to the group
    function addUserToGroup(address self, address sender, LibCommit.CollaborationData storage data, string memory group, address newUser) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        require(data.groups[groupHash].exists);
        require(data.groups[groupHash].containsUser[sender]);
        require(!data.groups[groupHash].containsUser[newUser]);

        data.groups[groupHash].containsUser[newUser] = true;
        data.groups[groupHash].users.push(newUser);
    }

    /// @dev Creates a new commit.
    /// @param self    Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param info    Info struct on the Platform
    /// @param data    All commit data on the Platform
    /// @param newCommit Details of the commit to be created
    function createCommit(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage platformData, LibCommit.CollaborationData storage data, LibCommit.NewCommit memory newCommit, string memory group) public {
        Commit storage parent = data.commits[newCommit.parent];
        require(newCommit.parent == bytes32(0) || data.groups[parent.group].containsUser[sender], "Must be in the parent commit's group to commit");
        
        // Create the commit!
        initCommit(sender, data, newCommit, group);
    }

    /// @dev Forks off of an existing commit and creates a new commit
    /// @param self       Address of contract calling this method: MatryxPlatform
    /// @param sender     msg.sender to the Platform
    /// @param info       Info struct on the Platform
    /// @param data       All commit data on the Platform
    /// @param newCommit  Commit to be created
    /// @param group      Group for the new commit
    function fork(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage platformData, LibCommit.CollaborationData storage data, LibCommit.NewCommit memory newCommit, string memory group) public {
        // Buy the subtree of the forked commit and distribute to ancestors
        distributeForkFunds(sender, info.token, platformData, data, newCommit.parent);

        // Create the commit!
        initCommit(sender, data, newCommit, group);
    }

    /// @dev Initializes a new commit
    /// @param creator    Creator of the commit
    /// @param group      Hash of the name of this commit's group
    /// @param data       All commit data on the Platform
    /// @param newCommit  Commit to be created
    function initCommit(address creator, LibCommit.CollaborationData storage data, LibCommit.NewCommit memory newCommit, string memory group) internal {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        bytes32 commitHash = keccak256(abi.encodePacked(newCommit.parent, newCommit.treeHash));

        require(data.groups[groupHash].containsUser[creator]);

        data.commits[commitHash].creator = creator;
        data.commits[commitHash].group = groupHash;
        data.commits[commitHash].commitHash = commitHash;
        data.commits[commitHash].treeHash = newCommit.treeHash;
        data.commits[commitHash].value = newCommit.value;
        data.commits[commitHash].totalValue = data.commits[newCommit.parent].totalValue.add(newCommit.value);
        data.commits[commitHash].height = data.commits[newCommit.parent].height + 1;
        data.commits[commitHash].parent = newCommit.parent;

        data.treeToCommit[newCommit.treeHash] = commitHash;

        if (newCommit.parent == bytes32(0)) {
            data.rootCommits.push(commitHash);
        } else {
            data.commits[newCommit.parent].children.push(commitHash);
        }

        emit Committed(commitHash, newCommit.treeHash);
    }

    /// @dev Distributes funds after a fork
    /// @param sender        Address to withdraw funds from
    /// @param token         Token address
    /// @param platformData  MatryxPlatform data
    /// @param data          Collaboration data
    /// @param commitHash    Commit hash to begin distributing funds back from
    function distributeForkFunds(address sender, address token, MatryxPlatform.Data storage platformData, LibCommit.CollaborationData storage data, bytes32 commitHash) internal {
        Commit storage commit = data.commits[commitHash];

        require(IToken(token).transferFrom(sender, address(this), commit.totalValue));
        platformData.totalBalance = platformData.totalBalance.add(commit.totalValue);
        
        for (uint256 i = commit.height; i > 0; i--) {
            platformData.balanceOf[commit.creator] = platformData.balanceOf[commit.creator].add(commit.value);
            commit = data.commits[commit.parent];
        }
    }
}
