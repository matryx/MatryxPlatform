pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;


import '../libraries/math/SafeMath.sol';
import '../libraries/strings/strings.sol';
import '../libraries/LibConstruction.sol';
import './reputation/SubmissionTrust.sol';
import '../interfaces/IMatryxToken.sol';
import '../interfaces/IMatryxPeer.sol';
import '../interfaces/IMatryxPlatform.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/IMatryxSubmission.sol';
import './Ownable.sol';

contract MatryxSubmission is Ownable, IMatryxSubmission {
    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeMath for uint32;
    using strings for *;


    /************** TODO ******************/
    /* COPY ALL FIELDS TO SUBMISSIONTRUST */           // <------------------ DON'T FORGET.
    /************** TODO ******************/


    // Parent identification
    address private platformAddress;
    address private tournamentAddress;
    address private roundAddress;

    // Submission
    string title;
    address author;
    bytes descriptionHash;
    bytes fileHash;
    address[] references;

    // Tracks the normalized trust gained through peers approving this submission
    mapping(address=>uint128) authorToApprovalTrustGiven;
    uint128 public approvalTrust;
    uint256 public totalPossibleTrust;
    address[] public approvingPeers;

    // Tracks the proportion of references this submission has approved
    mapping(address=>uint128_optional) missingReferenceToIndex;
    address[] public missingReferences;
    mapping(address=>ReferenceInfo) addressToReferenceInfo;
    mapping(address=>ReferenceStats) referenceStatsByAuthor;
    uint256 public approvedReferences;
    uint256 public totalReferenceCount;

    address[] contributors;
    mapping(address=>uint128) public contributorToBountyDividend;
    uint128 public contributorBountyDivisor;
    uint256 timeSubmitted;
    uint256 timeUpdated;
    bool public isPublic;

    address public trustDelegate;
    bytes4 fnSelector_addReference = bytes4(keccak256("addReference(address)"));
    bytes4 fnSelector_removeReference = bytes4(keccak256("removeReference(address)"));
    bytes4 fnSelector_approveReference = bytes4(keccak256("approveReference(address)"));
    bytes4 fnSelector_removeReferenceApproval = bytes4(keccak256("removeReferenceApproval(address)"));
    bytes4 fnSelector_flagMissingReference = bytes4(keccak256("flagMissingReference(address)"));
    bytes4 fnSelector_removeMissingReferenceFlag = bytes4(keccak256("removeMissingReferenceFlag(address)"));

    bytes4 fnSelector_revertIfReferenceFlagged = bytes4(keccak256("revertIfReferenceFlagged(address)"));

    constructor(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references, LibConstruction.RequiredSubmissionAddresses requiredAddresses, LibConstruction.SubmissionData submissionData) public
    {
        platformAddress = requiredAddresses.platformAddress;
        tournamentAddress = requiredAddresses.tournamentAddress;
        roundAddress = requiredAddresses.roundAddress;

        title = submissionData.title;
        owner = submissionData.owner;
        author = IMatryxPlatform(platformAddress).peerAddress(owner);
        require(author != 0x0);
        descriptionHash = submissionData.descriptionHash;
        fileHash = submissionData.fileHash;
        references = _references;
        trustDelegate = IMatryxPlatform(requiredAddresses.platformAddress).getSubmissionTrustLibrary();
        isPublic = submissionData.isPublic;

        for(uint32 i = 0; i < references.length;i++)
        {
            addressToReferenceInfo[references[i]].exists = true;
            addressToReferenceInfo[references[i]].index = i;
        }

        _addContributors(_contributors, _contributorRewardDistribution);
        
        contributors = _contributors;
        timeSubmitted = now;
    }

    /*
        * Structs
        */

    struct ReferenceInfo
    {
        uint32 index;
        bool exists;
        bool approved;
        bool flagged;
        uint128 negativeReputationAffect;
        uint128 positiveReputationAffect;
        uint128 authorReputation;
    }

    struct ReferenceStats
    {
        uint32 numberMissing;
        uint32 numberApproved;
    }

    struct uint128_optional
    {
        bool exists;
        uint128 value;
    }

    /*
        * Modifiers 
        */

    // modifier onlyAuthor() {
    //    	require(msg.sender == author);
    //    	_;
    //  	}

    modifier onlyPlatform() {
        require(msg.sender == platformAddress);
        _;
    }

    // modifier onlyRound()
    // {
    // 	require(msg.sender == roundAddress);
    // 	_;
    // }

    modifier ownerContributorOrRound()
    {
        require(msg.sender == owner || contributorToBountyDividend[msg.sender] != 0 || msg.sender == roundAddress);
        _;
    }

    modifier onlyPeer()
    {
        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        require(platform.isPeer(msg.sender));
        _;
    }

    // A modifier to ensure that information can only obtained
    // about this submission when it should be.
    modifier whenAccessible(address _requester)
    {
        require(isAccessible(_requester));
        _;
    }

    modifier duringOpenSubmission()
    {
        IMatryxRound round = IMatryxRound(roundAddress);
        require(round.getState() == 1);
        _;
    }

    /*
        * Getter Methods
        */

    function getTournament() public view returns (address) {
        return tournamentAddress;
    }

    function getRound() public view returns (address) {
        return roundAddress;
    }

    function isAccessible(address _requester) public view returns (bool)
    {
        IMatryxRound round = IMatryxRound(roundAddress);
        Ownable ownableTournament = Ownable(tournamentAddress);

        bool isPlatform = _requester == IMatryxTournament(tournamentAddress).getPlatform();
        bool isRound = _requester == roundAddress;
        bool ownsThisSubmission = _requester == owner;
        bool submissionExternallyAccessible = isPublic;
        bool roundAtLeastInReview = IMatryxRound(roundAddress).getState() >= 2;
        bool requesterIsEntrant = IMatryxTournament(tournamentAddress).isEntrant(_requester);
        bool requesterOwnsTournament = ownableTournament.getOwner() == _requester;
        bool requesterIsContributor = IMatryxRound(roundAddress).requesterIsContributor(_requester);
        bool duringReviewAndRequesterInTournament = roundAtLeastInReview && (requesterOwnsTournament || requesterIsEntrant || requesterIsContributor);
        // TODO: Have a discussion about what this means (also think about next steps (encryption))
        bool roundIsClosed = IMatryxRound(roundAddress).getState() >= 5;

        return isPlatform || isRound || ownsThisSubmission || submissionExternallyAccessible || duringReviewAndRequesterInTournament || IMatryxPlatform(platformAddress).isPeer(_requester) || IMatryxPlatform(platformAddress).isSubmission(_requester) || roundIsClosed;
    }

    function getTitle() public view whenAccessible(msg.sender) returns(string) {
        return title;
    }

    function getAuthor() public view whenAccessible(msg.sender) returns(address) {
        return author;
    }

    function getDescriptionHash() public view whenAccessible(msg.sender) returns (bytes)
    {
        return descriptionHash;
    }

    function getFileHash() public view whenAccessible(msg.sender) returns (bytes)
    {
        return fileHash;
    }

    function getReferences() public view whenAccessible(msg.sender) returns(address[]) {
        return references;
    }

    function getContributors() public view whenAccessible(msg.sender) returns(address[]) {
        return contributors;
    }

    function getTimeSubmitted() public view returns(uint256) {
        return timeSubmitted;
    }

    function getTimeUpdated() public view returns(uint256) {
        return timeUpdated;
    }

    /*
        * Setter Methods
        */

    function update(address[] _contributorsToAdd, uint128[] _contributorRewardDistribution, address[] _contributorsToRemove, LibConstruction.SubmissionModificationData _data)
    {
        if(!_data.title.toSlice().empty())
        {
            title = _data.title;
            timeUpdated = now;
        }
        if(_data.owner != 0x0)
        {
            owner = _data.owner;
            timeUpdated = now;
        }
        if(_data.descriptionHash.length != 0)
        {
            descriptionHash = _data.descriptionHash;
            timeUpdated = now;
        }
        if(_data.descriptionHash.length != 0)
        {
            fileHash = _data.fileHash;
            timeUpdated = now;
        }
        if(_data.isPublic)
        {
            isPublic = _data.isPublic;
            timeUpdated = now;
        }
        if(_contributorsToAdd.length != 0)
        {
            require(_contributorsToAdd.length == _contributorRewardDistribution.length);
            addContributors(_contributorsToAdd, _contributorRewardDistribution);
            timeUpdated = now;
        }
        if(_contributorsToRemove.length != 0)
        {
            removeContributors(_contributorsToRemove);
            timeUpdated = now;
        }
    }

    /// @dev Sets whether or not this submission can be accessed by anyone
    /// before the end of the tournament.
    function updateIsPublic(bool _public) public onlyOwner 
    {
        isPublic = _public;
    }

    /// @dev Edit the title of a submission (callable only by submission's owner).
    /// @param _title New title for the submission.
    function updateTitle(string _title) public onlyOwner duringOpenSubmission 
    {
        title = _title;
    }

    /// @dev Update the description hash of the submission (callable only by submission's owner).
    /// @param _descriptionHash New hash for the description of the submission.
    function updateDescription(bytes _descriptionHash) public onlyOwner duringOpenSubmission 
    {
        descriptionHash = _descriptionHash;
        timeUpdated = now;
    }

    /// @dev Update the file hash of the submission (callable only by submission's owner).
    /// @param _fileHash New hash for the body of the submission
    function updateFile(bytes _fileHash) public onlyOwner duringOpenSubmission
    {
        fileHash = _fileHash;
        timeUpdated = now;
    }

    function setTrustDelegate(address _newTrustDelegate) public onlyPlatform
    {
        trustDelegate = _newTrustDelegate;
    }

    /// @dev Add a missing reference to a submission (callable only by submission's owner).
    /// @param _reference Address of additional reference to include.

    function addReference(address _reference) onlyOwner public 
    {
        require(trustDelegate.delegatecall(fnSelector_addReference, _reference));
    }

    // // Debug function. ?MAYBEDO:Delete
    // function addressIsFlagged(address _reference) public view returns (bool, bool)
    // {
    // 	return (addressToReferenceInfo[_reference].flagged, missingReferenceToIndex[_reference].exists);
    // }

    /// @dev Remove an erroneous reference to a submission (callable only by submission's owner).
    /// @param _reference Address of reference to remove.

    function removeReference(address _reference) onlyOwner public
    {
        require(trustDelegate.delegatecall(fnSelector_removeReference, _reference));
    }

    function receiveReferenceRequest() public onlyPlatform
    {
        totalReferenceCount = totalReferenceCount.add(1);
    }

    function cancelReferenceRequest() public onlyPlatform
    {
        totalReferenceCount = totalReferenceCount.sub(1);
    }

    /// @dev Called by the owner of _reference when this submission is approved to list _reference
    /// as a reference.
    /// _reference Reference being approved by msg.sender.
    function approveReference(address _reference) public onlyPeer
    {
        require(trustDelegate.delegatecall(fnSelector_approveReference, _reference));
    }

    /// @dev 			  Called by the owner of the _reference to remove their approval of a reference
    ///		 			  within this submission.
    /// @param _reference Reference that peer is revoking the approval of to be included
    ///					  in this submission.
    function removeReferenceApproval(address _reference) public onlyPeer
    {
        require(trustDelegate.delegatecall(fnSelector_removeReferenceApproval, _reference));
    }

    /// @dev 	Called by the owner of _reference when this submission does not list _reference
    /// 		as a reference.
    /// @param  _reference Missing reference in this submission.
    function flagMissingReference(address _reference) public onlyPeer
    {
        require(trustDelegate.delegatecall(fnSelector_flagMissingReference, _reference));
    }

    /// @dev 			  Called by the owner of _reference to remove a missing reference flag placed on a reference
    ///		 			  as missing.
    /// @param _reference Reference previously marked by peer as missing.
    function removeMissingReferenceFlag(address _reference) public onlyPeer
    {
        require(trustDelegate.delegatecall(fnSelector_removeMissingReferenceFlag, _reference));
    }

    /// @dev Add a contributor to a submission (callable only by submission's owner).
    /// @param _contributor Address of contributor to add to the submission.
    function addContributor(address _contributor, uint128 _bountyAllocation) public onlyOwner
    {
        contributors.push(_contributor);

        contributorToBountyDividend[_contributor] = _bountyAllocation;
        contributorBountyDivisor = contributorBountyDivisor + _bountyAllocation;

        IMatryxRound round = IMatryxRound(roundAddress);
        round.setParticipantType(_contributor, 2);
    }

    function addContributors(address[] _contributorsToAdd, uint128[] _distribution) public onlyOwner
    {
        _addContributors(_contributorsToAdd, _distribution);
    }

    function _addContributors(address[] _contributorsToAdd, uint128[] _distribution) internal
    {
        require(_contributorsToAdd.length == _distribution.length);
        for(uint32 j = 0; j < _contributorsToAdd.length; j++)
        {
            // if one of the contributors is already there, revert
            // otherwise, add it to the list
            contributorBountyDivisor = contributorBountyDivisor + _distribution[j];
            contributorToBountyDividend[_contributorsToAdd[j]] = _distribution[j];
        }
    }

    /// @dev Remove a contributor from a submission (callable only by submission's owner).
    /// @param _contributorIndex Index of the contributor to remove from the submission.
    function removeContributor(uint256 _contributorIndex) onlyOwner public onlyOwner
    {
        contributorBountyDivisor = contributorBountyDivisor - contributorToBountyDividend[contributors[_contributorIndex]];
        contributorToBountyDividend[contributors[_contributorIndex]] = 0;

        delete contributors[_contributorIndex];
    }

    function removeContributors(address[] _contributorsToRemove) public onlyOwner
    {
        for(uint32 j = 0; j < _contributorsToRemove.length; j++)
        {
            contributorBountyDivisor = contributorBountyDivisor - contributorToBountyDividend[_contributorsToRemove[j]];
            contributorToBountyDividend[_contributorsToRemove[j]] = 0;
        }
    }

    function getBalance() public returns (uint256)
    {
        IMatryxRound round = IMatryxRound(roundAddress);
        uint256 _balance = round.getBalance(this);
        return _balance;
    }

    function withdrawReward(address _recipient) public ownerContributorOrRound
    {
        IMatryxToken token = IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress());
        uint256 submissionReward = IMatryxToken(token).balanceOf(address(this));

        // Transfer reward to submission author and contributors
        uint256 transferAmount = getTransferAmount();
        uint256 authorAmount = transferAmount.div(2);
        token.transfer(_recipient, authorAmount);
        // Distribute transfer amounts to contributors
        uint256 contributorsAmount = transferAmount.sub(authorAmount);
        for(uint i = 0; i < contributors.length; i++)
        {
            if(contributors[i] != 0x0)
            {
                uint256 contributionWeight = (contributorToBountyDividend[contributors[i]]).mul(1*10**18).div(contributorBountyDivisor);
                uint256 contributorReward = contributorsAmount.mul(contributionWeight).div(1*10**18);
                token.transfer(contributors[i], contributorReward);
            }
        }

        // Distribute remaining reward to references
        uint256 remainingReward = submissionReward.sub(transferAmount);
        for(uint j = 0; j < references.length; j++)
        {
            if(addressToReferenceInfo[references[j]].approved)
            {
                uint256 weight = (addressToReferenceInfo[references[j]].authorReputation).mul(1*10**18).div(totalPossibleTrust);
                uint256 weightedReward = remainingReward.mul(weight).div(1*10**18);
                token.transfer(references[j], weightedReward);
            }
        }
    }

    function getTransferAmount() public view returns (uint256)
    {
        uint submissionReward = getBalance();
        if(totalPossibleTrust == 0)
        {
            if(missingReferences.length > 0)
            {
                return 0;
            }

            return submissionReward;
        }

        // transfer amount calculated as:
        // normalizedAndReferenceCountWeightedTrustInSubmission * 
        // (1 - submissionGratitude) * 
        // submissionReward

        uint256 transferAmount = approvalTrust.mul(1*10**18 - IMatryxPlatform(platformAddress).getSubmissionGratitude());
        transferAmount = transferAmount.div(totalPossibleTrust);
        transferAmount = transferAmount.mul(submissionReward);
        transferAmount = transferAmount.div(1*10**18);

        return transferAmount;
    }

    // function prepareToDelete() internal
    // {
    // 	withdrawReward(owner);
    // 	// TODO: Remove references on other submissions so that MTX is not burned!
    // }

    // // @dev Removes a submission permanently.
    // 	// @param _recipient Address to send the refunded ether to.
    // function deleteSubmission() onlyRound public
    // {
    // 	prepareToDelete();
    // 	selfdestruct(author);
    // }
}