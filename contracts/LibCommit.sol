pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./IMatryxToken.sol";
import "./SafeMath.sol";

library LibCommit {
    using SafeMath for uint256;

    struct CollaborationData {
        mapping(bytes32=>Commit) commits;                                      // commit hash to commit struct mapping
        bytes32[] allCommits;                                                  // array of all commit hashes
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
    /// @param newUser Requested user to join the group
    function requestToJoinGroup(address self, address sender, CollaborationData storage data, string memory group, address newUser) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        emit JoinGroupRequest(group, newUser);
    }

    /// @dev Adds a user to a group
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param group Name of the group
    /// @param newUser User to add to the group
    function addUserToGroup(address self, address sender, CollaborationData storage data, string memory group, address newUser) public {
        bytes32 groupHash = keccak256(abi.encodePacked(group));
        if(data.groups[groupHash].exists) {
            require(data.groups[groupHash].exists);
            require(data.groups[groupHash].containsUser[sender]);
            require(!data.groups[groupHash].containsUser[newUser]);
        }
        else {
            data.groups[groupHash].exists = true;
            data.groups[groupHash].containsUser[sender] = true;
            data.allGroups.push(groupHash);
            data.groups[groupHash].users.push(sender);
        }

        data.groups[groupHash].containsUser[newUser] = true;
        data.groups[groupHash].users.push(newUser);
        // TODO: Worry about distributions
    }

    // "0x1234567890123456789012345678901234567890123456789012345678901234", "0x1234567890123456789012345678901234567890123456789012345678901234", ["0x1234567890123456789012345678901234567890123456789012345678901234", "0x1234567890123456789012345678901234567890123456789012345678901234"], 5, 5, 5
    /// @dev Creates a new commit.
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param token Address of MatryxToken
    /// @param commitDetails Details of the commit to be created
    /// @param leftPath Most valuable (longest) path backwards from this commit to a virtual parent (merges only)
    /// @param rightPath Most valuable (longest) path backwards from this commit to a virtual parent (merges only)
    function createCommit(address self, address sender, address token, CollaborationData storage data, CommitDetails memory commitDetails, bytes32 group, Path memory leftPath, Path memory rightPath) public {
        Commit storage parent0 = data.commits[commitDetails.parents[0].rootHash];
        Commit storage parent1 = data.commits[commitDetails.parents[1].rootHash];
        require(parent0.exists);
        // require(group == parent0.group || group == parent1.group);
        // TODO: Handle where this is not the case, if you aren't already
        require(leftPath.length == rightPath.length);

        // Transfer MTX if sender is not in a parent commit's group
        if (!data.groups[parent0.group].containsUser[sender])
        {
            require(IMatryxToken(token).transferFrom(sender, parent0.creator, parent0.details.usePrice));
        }
        if (!data.groups[parent1.group].containsUser[sender])
        {
            require(IMatryxToken(token).transferFrom(sender, parent1.creator, parent1.details.usePrice));
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
        data.commits[commitHash].details.parents[1] = commitDetails.parents[1];

        if(leftPath.length != 0)
        {
            Commit storage newCommit = data.commits[commitHash];
            // TODO: begin implementing merge with new logic (groups, etc)
            uint256 leftPathValue;
            uint256 rightPathValue;
            bytes32[2] memory ancestor;

            CommitDetails storage backwalkCommit = data.commits[commitHash].details;
            uint256 theByte;
            uint256 theBit;
            uint256 i;
            for(i = 0; i < leftPath.length*8; i++)
            {
                theByte = i/8;
                theBit = uint8((leftPath.path[theByte] >> i) & 0x01);

                leftPathValue += backwalkCommit.parents[theBit].givenValue;
                ancestor[0] = backwalkCommit.parents[theBit].rootHash;

                backwalkCommit = data.commits[backwalkCommit.parents[theBit].rootHash].details;
            }

            backwalkCommit = data.commits[commitHash].details;
            for(i = 0; i < rightPath.length*8; i++)
            {
                theByte = i/8;
                theBit = uint8((rightPath.path[theByte] >> i) & 0x01);

                rightPathValue += backwalkCommit.parents[theBit].givenValue;
                ancestor[1] = backwalkCommit.parents[theBit].rootHash;

                backwalkCommit = data.commits[backwalkCommit.parents[theBit].rootHash].details;
            }

            require(ancestor[0] == ancestor[1]);

            // Set size and value of commit
            newCommit.details.value = leftPathValue + rightPathValue + data.commits[ancestor[0]].details.value;
            newCommit.details.height = leftPath.length + rightPath.length + data.commits[ancestor[0]].details.height;
            // Set parent sizes and values
            newCommit.details.parents[0].rootHash = commitDetails.parents[0].rootHash;
            newCommit.details.parents[0].accHeight = leftPath.length + data.commits[ancestor[0]].details.height;
            newCommit.details.parents[0].accValue = leftPathValue + data.commits[ancestor[0]].details.value;
            newCommit.details.parents[1].rootHash = commitDetails.parents[1].rootHash;
            newCommit.details.parents[1].accHeight = rightPath.length + data.commits[ancestor[1]].details.height;
            newCommit.details.parents[1].accValue = rightPathValue + data.commits[ancestor[1]].details.value;
            // Create virtual parent
            newCommit.details.parents[2].rootHash = ancestor[0];
            newCommit.details.parents[2].givenValue = leftPathValue + rightPathValue;
            // TODO: Are these values correct?
            newCommit.details.parents[2].accHeight = leftPath.length + rightPath.length + data.commits[ancestor[0]].details.height;
            newCommit.details.parents[2].accValue = leftPathValue + rightPathValue + data.commits[ancestor[0]].details.value;
        }

        emit Committed(commitHash, commitDetails.treeHash);
    }

    /// @dev Sets the price to branch from a particular commit
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param commitHash Hash of the commmit to set the price of
    /// @param usePrice New price to work off of the commit
    function setCommitPrice(address self, address sender, CollaborationData storage data, bytes32 commitHash, uint256 usePrice) public {
        require(data.commits[commitHash].creator == sender);
        if(usePrice != 0) {
            data.commits[commitHash].details.usePrice = usePrice;
        }
    }

    /// @dev Bid on a particular commit.
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param commitHash The hash of the commit being bid on.
    /// @param bid The bid for the commit.
    function bidCommit(address self, address sender, CollaborationData storage data, bytes32 commitHash, uint256 bid) public  {
        emit Bid(commitHash, sender, bid);
    }

    /// @dev Sell a particular commit after its been bid on
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param commitHash The hash of the commit to sell.
    /// @param bidder The address to sell the commit to.
    function sellCommit(address self, address sender, address token, CollaborationData storage data, bytes32 commitHash, address bidder, uint256 bid) public {
        require(data.commits[commitHash].exists == true, "This commit does not exist");
        require(sender == data.commits[commitHash].creator, "You must own a commit to sell it");
        require(IMatryxToken(token).transferFrom(bidder, data.commits[commitHash].creator, bid), "Sell transaction must go through");
        emit Sold(commitHash, bid, bidder);
    }
}