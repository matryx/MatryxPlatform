pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

import "./IMatryxToken.sol";
import "./SafeMath.sol";

library LibCommitment
{
    using SafeMath for uint256;

    struct CommitData
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
    event Sold(bytes32 commitHash, uint256 workPrice, address _newOwner);      // Fired when a commit is sold by its owner
    event Committed(bytes32 commitHash, bytes32 _mergeTree);                   // Fired when a new commit is created

    struct User
    {
        mapping(bytes32=>uint256) bids;                                        // Bids on a particular commit
        bytes groupMask;                                                       // Groups marked by bid
    }

    struct Commit
    {
        address groupAddress;
        Subtree subtree;
        bool exists;
        CommitDetails details;
        mapping(bytes32=>CommitDetails) mergeRequests;
    }

    struct Subtree
    {
        uint256 size;
        uint256 value;
    }

    struct CommitDetails
    {
        bytes32 commitHash;
        bytes32 branchHash;
        bytes32 treeHash;
        uint256 workPrice;
        uint256 mergeInclinationValue;
        bytes32[2] parents;
        VirtualParent[] virtualParents;
    }

    struct VirtualParent {
        bytes32 parentHash;
        uint256 totalValue;
        uint256 minimumValue;
        uint256 minimumSteps;
        bytes32 minPathHash;
    }

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
    function requestToJoinGroup(address self, address sender, CommitData storage data, string group, address newUser) public {
        bytes32 groupHash = keccak256(group);
        emit JoinGroupRequest(group, newUser);
    }

    /// @dev Adds a user to a group
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param group Name of the group
    /// @param newUser User to add to the group
    function addUserToGroup(address self, address sender, CommitData storage data, string group, address newUser) public {
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
    function createCommit(address self, address sender, CommitData storage data, address token, CommitDetails commitDetails, bytes leftPath, bytes rightPath) public {
        require(leftPath.length == rightPath.length);
        Commit storage parent0 = data.commits[commitDetails.parents[0]];
        Commit storage parent1 = data.commits[commitDetails.parents[1]];
        require(parent0 != 0x0);

        uint256 numParents = parent1 != 0x0 ? 2 : 1;
        // uint256[2] memory parentPrices = uint256[2](parent0.details.workPrice, parent1.details.workPrice);

        // TODO: begin implementing merge with new logic (groups, no branches, virtual parent addition, not in group means paying, etc)
        // uint256 price = parent0.details.workPrice + parent1.details.workPrice;
        uint256 lPathPrice;
        uint256 rPathPrice;
        bytes32 vParentHashLeft;
        bytes32 vParentHashRight;

        bytes32 currCommitHash = commitDetails.parents[0];
        Commit storage tempParent;
        for(uint256 i = 1; i < leftPath.length; i++)
        {
            lPathPrice += data.commits[currCommitHash];
            vParentHashLeft = currCommitHash;

            tempParent = data.commits[data.commits[currCommitHash].details.parents[leftPath[i]]];
            currCommitHash = tempParent.commitHash;
        }

        currCommitHash = commitDetails.parents[1];
        for(i = 1; i < leftPath.length; i++)
        {
            rPathPrice += data.commits[currCommitHash];
            vParentHashRight = currCommitHash;
            
            tempParent = data.commits[data.commits[currCommitHash].details.parents[rightPath[i]]];              // You were about to set the value of the commit in the merge case
            currCommitHash = tempParent.commitHash;                                                             // but you realized you didn't know how to calculate it because double spending
        }

        require(vParentHashLeft == vParentHashRight);

        // Create the commit! (for later: this is a parent block hash)
        bytes32 commitHash = keccak256(abi.encodePacked(parent0, parent1));
        data.treeToCommit[commitDetails.treeHash] = commitHash;

        // Not gas optimized
        Commit memory newCommit;
        newCommit.owner = sender;
        newCommit.details = commitDetails;
        newCommit.details.commitHash = commitHash;
        // newCommit.subtree.size = numParents + parent0.subtreeSize + parent1.subtreeSize;    // resolve these two (merge flag)
        // newCommit.subtree.size = data.commits[vParentHashLeft].size + 2;
        // newCommit.subtree.value = parent0.subtreeValue + parent1.subtreeValue;
        // newCommit.subtree.value = data.commits[vParentHashLeft].value
        newCommit.exists = true;

        data.commits[commitHash] = newCommit;
        emit Committed(commitHash, commitDetails.treeHash);
    }

    /// @dev Sets the price to branch from a particular commit
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param commitHash Hash of the commmit to set the price of
    /// @param workPrice New price to work off of the commit
    function setCommitPrice(address self, address sender, CommitData storage data, bytes32 commitHash, uint256 workPrice) public {
        require(data.commits[commitHash].owner == sender);
        if(workPrice != 0) {
            data.commits[commitHash].details.workPrice = workPrice;
        }
    }

    /// @dev Bid on a particular commit.
    /// @param self  Address of contract calling this method: MatryxPlatform
    /// @param sender  msg.sender to the Platform
    /// @param data All commit data on the Platform
    /// @param commitHash The hash of the commit being bid on.
    /// @param bid The bid for the commit.
    function bidCommit(address self, address sender, CommitData storage data, bytes32 commitHash, uint256 bid) public
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
    function sellCommit(address self, address sender, CommitData storage data, bytes32 commitHash, address bidder) public {
        // The commit has to exist
        require(data.commits[commitHash].owner != 0x0);
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