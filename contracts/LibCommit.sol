pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

import "./IMatryxToken.sol";
import "./SafeMath.sol";

library LibCommit
{
    using SafeMath for uint256;

    struct CollaborationData
    {
        mapping(bytes32=>Commit) commits;                                      // commit hash to commit struct mapping
        mapping(bytes32=>Group) groups;                                        // group mask hash to group struct mapping
        mapping(address=>bytes32) groupNameToNumber;                           // group address to group mask
        mapping(bytes32=>bytes32) treeToCommit;                                // top level directory hash to commit hash mapping
        mapping(address=>User) users;                                          // user address to user struct mapping
        bytes32[] allCommits;                                                  // array of all commit hashes
        bytes32[] allGroups;                                                   // array of all group(name) hashes, length is new group number
    }

    event Bid(bytes32 _commit, address bidder, uint256 bid);                   // Fired when someone bids on a commit
    event JoinGroupRequest(string group, address user);                        // Fired when someone requests to join a group
    event Sold(bytes32 commitHash, uint256 usePrice, address _newOwner);      // Fired when a commit is sold by its owner
    event Committed(bytes32 commitHash, bytes32 _mergeTree);                   // Fired when a new commit is created

    struct User
    {
        mapping(bytes32=>uint256) bids;                                        // Bids on a particular commit
        bytes groupMask;                                                       // Groups marked by bid
    }

    struct Commit
    {
        bool exists;
        address groupAddress;
        CommitDetails details;
        mapping(bytes32=>CommitDetails) mergeRequests;
    }

    struct CommitDetails
    {
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
    struct SubtreeInfo
    {
        bytes32 rootHash;
        uint256 givenValue;
        uint256 accHeight;
        uint256 accValue;
    }

    /// @dev Represents a path to a specific ancestor commit.
    /// @param path The path in 0:=left_parent,1:=right_parent encoded bits.
    /// @param length The length of the path in bits
    struct Path
    {
        bytes path;
        uint256 length;
    }

    // struct VirtualParent {
    //     bytes32 parentHash;
    //     uint256 totalValue;
    //     uint256 minimumValue;
    //     uint256 minimumSteps;
    //     bytes32 minPathHash;
    // }

    struct Group {
        bool exists;
        mapping(address=>bool) userExists;
        address[] users;
        uint256 defaultDistribution;
        uint256[] allDistributions;
    }

    struct Distribution {
        bytes32 groupHash;
        uint256 distributionIndex;
    }

    /// @dev Request to join a group
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param group Name of the group to request access to
    /// @param newUser Requested user to join the group
    function requestToJoinGroup(address self, address sender, CollaborationData storage data, string group, address newUser) public {
        bytes32 groupHash = keccak256(group);
        emit JoinGroupRequest(group, newUser);
    }

    /// @dev Adds a user to a group
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param group Name of the group
    /// @param newUser User to add to the group
    function addUserToGroup(address self, address sender, CollaborationData storage data, string group, address newUser) public {
        bytes32 groupHash = keccak256(group);
        if(data.groups[groupHash].exists) {
            require(data.groups[groupHash].exists);
            require(data.groups[groupHash].userExists[sender]);
            require(!data.groups[groupHash].userExists[newUser]);
        }
        else {
            data.groups[groupHash].exists = true;
            data.groups[groupHash].userExists[sender] = true;
            data.allGroups.push(groupHash);
            data.groups[groupHash].users.push(sender);
        }

        data.groups[groupHash].userExists[newUser] = true;
        data.groups[groupHash].users.push(newUser);
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
    function createCommit(address self, address sender, address token, CollaborationData storage data, CommitDetails commitDetails, bytes32 groupAddress, Path leftPath, Path rightPath) public {
        Commit storage parent0 = data.commits[commitDetails.parents[0].rootHash];
        Commit storage parent1 = data.commits[commitDetails.parents[1].rootHash];
        require(parent0.exists);
        require(leftPath.length == rightPath.length);
        
        bytes32 commitHash = keccak256(abi.encodePacked(commitDetails.parents[0].rootHash, commitDetails.parents[1].rootHash));
        Commit memory memCommit;
        memCommit.exists = true;
        memCommit.owner = sender;
        memCommit.groupAddress = groupAddress;
        memCommit.details = commitDetails;
        memCommit.details.parents[0].givenValue = parent0.details.usePrice;
        memCommit.details.parents[1].givenValue = parent1.details.usePrice;

        // Create the commit! (for later: this is a parent block hash)
        data.treeToCommit[commitDetails.treeHash] = commitHash;
        data.commits[commitHash] = memCommit;

        if(leftPath != 0x0)
        {
            // TODO: begin implementing merge with new logic (groups, no branches, virtual parent addition, not in group means paying, etc)
            uint256 leftPathValue;
            uint256 rightPathValue;
            bytes32 virtualParentLeft;
            bytes32 virtualParentRight;

            CommitDetails storage backwalkCommit = data.commits[commitHash];
            for(uint256 i = 0; i < leftPath.length; i++)
            {
                uint256 theByte = i/8;
                uint8 theBit = (leftPath[theByte] >> i) & 0x01;

                leftPathValue += backwalkCommit.parents[theBit].givenValue;
                virtualParentLeft = backwalkCommit.parents[theBit].rootHash;

                backwalkCommit = data.commits[backwalkCommit.parents[theBit].rootHash];
            }

            backwalkCommit = data.commits[commitHash];
            for(i = 0; i < rightPath.length; i++)
            {
                uint256 theByte = i/8;
                uint8 theBit = (rightPath[theByte] >> i) & 0x01;

                rightPathValue += backwalkCommit.parents[theBit].givenValue;
                virtualParentRight = backwalkCommit.parents[theBit].rootHash;

                backwalkCommit = data.commits[backwalkCommit.parents[theBit].rootHash];
            }

            require(virtualParentLeft == virtualParentRight);

            // Set size and value of commit
            newCommit.details.value = leftPathValue + rightPathValue + data.comits[virtualParentLeft].details.value;
            newCommit.details.height = leftPath.length + rightPath.length + data.commits[virtualParentLeft].details.height;
            // Set parent sizes and values
            newCommit.details.parents[0].rootHash = commitDetails.parents[0].rootHash;
            newCommit.details.parents[0].accHeight = leftPath.length + data.commits[virtualParentLeft].details.height;
            newCommit.details.parents[0].accValue = leftPathValue + data.commits[virtualParentLeft].details.value;
            newCommit.details.parents[1].rootHash = commitDetails.parents[1].rootHash;
            newCommit.details.parents[1].accHeight = rightPath.length + data.commits[virtualParentRight].details.height;
            newCommit.details.parents[1].accValue = rightPathValue + data.commits[virtualParentRight].details.value;
            // Create virtual parent
            newCommit.details.parents[2].rootHash = virtualParentLeft;
            newCommit.details.parents[2].givenValue = leftPathValue + rightPathValue;
            newCommit.details.parents[2].accHeight = leftPath.length + rightPath.length + data.commits[virtualParentLeft].details.height;
            newCommit.details.parents[2].accValue = leftPathValue + rightPathValue + data.commits[virtualParentLeft].details.value;
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
        require(data.commits[commitHash].owner == sender);
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
    function bidCommit(address self, address sender, CollaborationData storage data, bytes32 commitHash, uint256 bid) public
    {
        data.users[sender].bids[commitHash] = bid;
        emit Bid(commitHash, sender, bid);
    }

    /// @dev Sell a particular commit after its been bid on
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param commitHash The hash of the commit to sell.
    /// @param bidder The address to sell the commit to.
    function sellCommit(address self, address sender, CollaborationData storage data, bytes32 commitHash, address bidder) public {
        // The commit has to exist
        require(data.commits[commitHash].exists = true;
        // The person has to have bid on this commit
        require(data.users[bidder].bids[commitHash] != 0);
        require(sender == data.commits[commitHash].owner);

        // The buy must go through
        require(IMatryxToken(token).transferFrom(bidder, data.commits[commitHash].owner, data.users[bidder].bids[commitHash]));
        // Now it's theirs
        data.commits[commitHash].owner = bidder;
        data.users[bidder].bids[commitHash] = 0;

        emit Sold(commitHash, data.users[bidder].bids[commitHash], bidder);
    }
}