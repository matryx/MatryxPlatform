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
    function requestToJoinGroup(string calldata group) external;
    function addUserToGroup(string calldata group, address newUser) external;
    function createCommit(LibCommit.CommitDetails calldata commitDetails, bytes32 group, LibCommit.Path calldata leftPath, LibCommit.Path calldata rightPath) external;
    function setCommitPrice(bytes32 commitHash, uint256 usePrice) external;
    function bidCommit(bytes32 commitHash, uint256 bid) external ;
    function sellCommit(bytes32 commitHash, address bidder, uint256 bid) external;
}

library LibCommit {
    using SafeMath for uint256;

    struct CollaborationData {
        mapping(bytes32=>Commit) commits;                                      // commit hash to commit struct mapping
        bytes32[] rootCommits;                                                 // all root level commits (no parents)
        mapping(bytes32=>Group) groups;                                        // group mask hash to group struct mapping
        bytes32[] allGroups;                                                   // array of all group(name) hashes. length is new group number
        mapping(bytes32=>bytes32) treeToCommit;                                // top level directory hash to commit hash mapping
    }

    event Bid(bytes32 _commit, address bidder, uint256 bid);                   // Fired when someone bids on a commit
    event JoinGroupRequest(string group, address user);                        // Fired when someone requests to join a group
    event Sold(bytes32 commitHash, uint256 usePrice, address _newOwner);       // Fired when a commit is sold by its owner
    event Committed(bytes32 commitHash, bytes32 _mergeTree);                   // Fired when a new commit is created

    struct Commit {
        bool exists;
        address creator;
        bytes32 group;
        CommitDetails details;
        mapping(bytes32=>CommitDetails) mergeRequests;
        bytes32[] children;
    }

    struct CommitDetails {
        bytes32 commitHash;
        bytes32 treeHash;
        uint256 usePrice;
        uint256 value;
        uint256 height;
        SubtreeInfo[] parents;
    }

    ///@dev Information about a subtree under a commit
    ///@param rootHash Hash of the root of the subtree
    ///@param givenValue Value paid by commit to include this parent commit
    ///@param accHeight Length of subtree from root commit to this parent
    ///@param accValue Accumulated value from root commit to this parent
    struct SubtreeInfo {
        bytes32 rootHash;
        uint256 givenValue;
        uint256 accHeight;
        uint256 accValue;
    }

    /// @dev Represents a path to a specific ancestor commit.
    /// @param path The path in 0:=left_parent,1:=right_parent encoded bits.
    /// @param length The length of the path in bits
    struct Path {
        bytes path;
        uint256 length;
    }

    struct Group {
        bool exists;
        mapping(address=>bool) containsUser;
        address[] users;
        // TODO: Worry about this
        // uint256[] distribution;
        // mapping(address=>uint256) deltaDistributionByUser;
    }

    /// @dev Request to join a group
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param group Name of the group to request access to
    function requestToJoinGroup(address self, address sender, LibCommit.CollaborationData storage data, string memory group) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        emit JoinGroupRequest(group, sender);
    }

    /// @dev Adds a user to a group
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param group Name of the group
    /// @param newUser User to add to the group
    function addUserToGroup(address self, address sender, LibCommit.CollaborationData storage data, string memory group, address newUser) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        if (data.groups[groupHash].exists) {
            require(data.groups[groupHash].exists);
            require(data.groups[groupHash].containsUser[sender]);
            require(!data.groups[groupHash].containsUser[newUser]);
        }
        else {
            data.groups[groupHash].exists = true;
            data.allGroups.push(groupHash);

            data.groups[groupHash].containsUser[sender] = true;
            data.groups[groupHash].users.push(sender);
        }

        data.groups[groupHash].containsUser[newUser] = true;
        data.groups[groupHash].users.push(newUser);
        // TODO: Worry about distributions
    }

    /// @dev Creates a new commit.
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param info Info struct on the Platform
    /// @param data All commit data on the Platform
    /// @param commitDetails Details of the commit to be created
    /// @param leftPath Most valuable (longest) path backwards from this commit to a virtual parent (merges only)
    /// @param rightPath Most valuable (longest) path backwards from this commit to a virtual parent (merges only)
    function createCommit(address self, address sender, MatryxPlatform.Info storage info, LibCommit.CollaborationData storage data, LibCommit.CommitDetails memory commitDetails, bytes32 group, LibCommit.Path memory leftPath, LibCommit.Path memory rightPath) public {
        Commit storage parent0 = data.commits[commitDetails.parents[0].rootHash];
        require(parent0.exists);
        // require(group == parent0.group || group == parent1.group);
        // TODO: Handle where this is not the case, if you aren't already
        require(leftPath.length == rightPath.length);

        // Transfer MTX if sender is not in a parent commit's group
        if (!data.groups[parent0.group].containsUser[sender]) {
            require(IToken(info.token).transferFrom(sender, parent0.creator, parent0.details.value));
        }
        
        bytes32 commitHash = keccak256(abi.encodePacked(commitDetails.parents[0].rootHash, commitDetails.parents[1].rootHash));
        // Create the commit! (for later: this is a parent block hash)
        data.commits[commitHash].exists = true;
        data.commits[commitHash].creator = sender;
        data.commits[commitHash].group = group;
        data.commits[commitHash].details.commitHash = commitDetails.commitHash;
        data.commits[commitHash].details.treeHash = commitDetails.treeHash;
        data.commits[commitHash].details.usePrice = commitDetails.usePrice;
        data.commits[commitHash].details.value = commitDetails.value;
        data.commits[commitHash].details.height = commitDetails.height;
        data.commits[commitHash].details.parents[0] = commitDetails.parents[0];

        emit Committed(commitHash, commitDetails.treeHash);
    }

    /// @dev Sets the price to branch from a particular commit
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param commitHash Hash of the commmit to set the price of
    /// @param usePrice New price to work off of the commit
    function setCommitPrice(address self, address sender, LibCommit.CollaborationData storage data, bytes32 commitHash, uint256 usePrice) public {
        require(data.commits[commitHash].creator == sender);
        if (usePrice != 0) {
            data.commits[commitHash].details.usePrice = usePrice;
        }
    }

    /// @dev Bid on a particular commit.
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param commitHash The hash of the commit being bid on.
    /// @param bid The bid for the commit.
    function bidCommit(address self, address sender, LibCommit.CollaborationData storage data, bytes32 commitHash, uint256 bid) public  {
        emit Bid(commitHash, sender, bid);
    }

    /// @dev Sell a particular commit after its been bid on
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param commitHash The hash of the commit to sell.
    /// @param bidder The address to sell the commit to.
    function sellCommit(address self, address sender, MatryxPlatform.Info storage info, LibCommit.CollaborationData storage data, bytes32 commitHash, address bidder, uint256 bid) public {
        require(data.commits[commitHash].exists == true, "This commit does not exist");
        require(sender == data.commits[commitHash].creator, "You must own a commit to sell it");
        require(IToken(info.token).transferFrom(bidder, data.commits[commitHash].creator, bid), "Sell transaction must go through");
        emit Sold(commitHash, bid, bidder);
    }
}