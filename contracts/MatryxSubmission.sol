pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;


import "../libraries/math/SafeMath.sol";
import "../libraries/math/SafeMath128.sol";
import "../libraries/strings/strings.sol";
import "../libraries/LibConstruction.sol";
import "../libraries/LibEnums.sol";
import "../libraries/submission/LibSubmission.sol";
import "../libraries/submission/LibSubmissionTrust.sol";
import "../interfaces/IMatryxToken.sol";
import "../interfaces/IMatryxPeer.sol";
import "../interfaces/IMatryxPlatform.sol";
import "../interfaces/IMatryxTournament.sol";
import "../interfaces/IMatryxRound.sol";
import "../interfaces/IMatryxSubmission.sol";
import "./Ownable.sol";

contract MatryxSubmission is Ownable, IMatryxSubmission {
    using SafeMath for uint256;
    using SafeMath128 for uint128;
    using SafeMath for uint32;
    using strings for *;

    // Parent identification
    address private platformAddress;
    address private tournamentAddress;
    address private roundAddress;

    // Submission
    LibConstruction.SubmissionData data;
    LibSubmission.RewardData rewardData;
    LibSubmission.TrustData trustData;
    LibConstruction.ContributorsAndReferences contributorsAndReferences;

    address author;

    uint256 one = 10**18;

    constructor(address _owner, address _platformAddress, address _tournamentAddress, address _roundAddress, LibConstruction.SubmissionData _submissionData) public
    {
        platformAddress = _platformAddress;
        tournamentAddress = _tournamentAddress;
        roundAddress = _roundAddress;

        data = _submissionData;
        owner = _owner;
        author = IMatryxPlatform(platformAddress).peerAddress(_owner);
        require(author != 0x0);

        data.timeSubmitted = now;
        data.timeUpdated = now;
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
        require(msg.sender == owner || rewardData.contributorToBountyDividend[msg.sender] != 0 || msg.sender == roundAddress);
        _;
    }

    modifier onlyPeer()
    {
        require(IMatryxPlatform(platformAddress).isPeer(msg.sender));
        _;
    }

    // A modifier to ensure that information can only obtained
    // about this submission when it should be.
    modifier whenAccessible(address _requester)
    {
        require(isAccessible(_requester));
        _;
    }

    modifier onlySubmissionOrRound()
    {
        require(msg.sender == roundAddress || IMatryxRound(roundAddress).submissionExists(msg.sender));
        _;
    }

    modifier onlyOwnerOrThis()
    {
        require(msg.sender == owner || msg.sender == address(this));
        _;
    }

    modifier duringOpenSubmission()
    {
        require(IMatryxRound(roundAddress).getState() == uint256(LibEnums.RoundState.Open));
        _;
    }

    /*
    * Getter Methods
    */

    function() public {
        assembly {
            mstore(0, 0xdead)
            log0(0x1e, 0x02)
            mstore(0, calldataload(0x0))
            log0(0, 0x04)
        }
    }

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
        bool roundAtLeastInReview = IMatryxRound(roundAddress).getState() >= uint256(LibEnums.RoundState.InReview);
        bool requesterIsEntrant = IMatryxTournament(tournamentAddress).isEntrant(_requester);
        bool requesterOwnsTournament = ownableTournament.getOwner() == _requester;
        bool duringReviewAndRequesterInTournament = roundAtLeastInReview && (requesterOwnsTournament || requesterIsEntrant);
        // TODO: think about next steps (encryption)
        bool roundIsClosed = IMatryxRound(roundAddress).getState() >= uint256(LibEnums.RoundState.Closed);

        return isPlatform || isRound || ownsThisSubmission || duringReviewAndRequesterInTournament || IMatryxPlatform(platformAddress).isPeer(_requester) || IMatryxPlatform(platformAddress).isSubmission(_requester) || roundIsClosed;
    }

    function getData() public view whenAccessible(msg.sender) returns(LibConstruction.SubmissionData _data)
    {
        return data;
    }

    function getTitle() public view whenAccessible(msg.sender) returns(bytes32[3]) {
        return data.title;
    }

    function getAuthor() public view whenAccessible(msg.sender) returns(address) {
        return author;
    }

    function getDescriptionHash() public view whenAccessible(msg.sender) returns (bytes32[2])
    {
        return data.descriptionHash;
    }

    function getFileHash() public view whenAccessible(msg.sender) returns (bytes32[2])
    {
        return data.fileHash;
    }

    function getReferences() public view whenAccessible(msg.sender) returns(address[]) {
        return contributorsAndReferences.references;
    }

    function getContributors() public view whenAccessible(msg.sender) returns(address[]) {
        return contributorsAndReferences.contributors;
    }

    function getTimeSubmitted() public view returns(uint256) {
        return data.timeSubmitted;
    }

    function getTimeUpdated() public view returns(uint256) {
        return data.timeUpdated;
    }

    function getTotalWinnings() public view returns(uint256) {
        return rewardData.winnings;
    }

    /*
    * Setter Methods
    */

    function updateData(LibConstruction.SubmissionModificationData _modificationData) public onlyOwner duringOpenSubmission
    {
        LibSubmission.updateData(data, _modificationData);
    }

    function updateContributors(LibConstruction.ContributorsModificationData _contributorsModificationData) public onlyOwner duringOpenSubmission
    {
        LibSubmission.updateContributors(data, contributorsAndReferences, rewardData, _contributorsModificationData);
    }

    function updateReferences(LibConstruction.ReferencesModificationData _referencesModificationData) public onlyOwner duringOpenSubmission
    {
        LibSubmission.updateReferences(platformAddress, data, contributorsAndReferences, trustData, _referencesModificationData);
    }

    function addToWinnings(uint256 _amount) public onlySubmissionOrRound
    {
        rewardData.winnings = rewardData.winnings.add(_amount);
    }

    /// @dev Add a missing reference to a submission (callable only by submission's owner).
    /// @param _reference Address of additional reference to include.

    function addReference(address _reference) public onlyOwner
    {
        LibSubmissionTrust.addReference(platformAddress, contributorsAndReferences, trustData, _reference);
    }

    function addReferences(address[] _references) public onlyOwner
    {
        LibSubmissionTrust.addReferences(platformAddress, contributorsAndReferences, trustData, _references);
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
        LibSubmissionTrust.removeReference(platformAddress, contributorsAndReferences, trustData, _reference);
    }

    function receiveReferenceRequest() public onlyPlatform
    {
        trustData.totalReferenceCount = trustData.totalReferenceCount.add(1);
    }

    function cancelReferenceRequest() public onlyPlatform
    {
        trustData.totalReferenceCount = trustData.totalReferenceCount.sub(1);
    }

    /// @dev Called by the owner of _reference when this submission is approved to list _reference
    /// as a reference.
    /// _reference Reference being approved by msg.sender.
    function approveReference(address _reference) public onlyPeer
    {
        LibSubmissionTrust.approveReference(trustData, _reference);
    }

    /// @dev 			  Called by the owner of the _reference to remove their approval of a reference
    ///		 			  within this submission.
    /// @param _reference Reference that peer is revoking the approval of to be included
    ///					  in this submission.
    function removeReferenceApproval(address _reference) public onlyPeer
    {
        LibSubmissionTrust.removeReferenceApproval(trustData, _reference);
    }

    /// @dev 	Called by the owner of _reference when this submission does not list _reference
    /// 		as a reference.
    /// @param  _reference Missing reference in this submission.
    function flagMissingReference(address _reference) public onlyPeer
    {
        LibSubmissionTrust.flagMissingReference(trustData, _reference);
    }

    /// @dev 			  Called by the owner of _reference to remove a missing reference flag placed on a reference
    ///		 			  as missing.
    /// @param _reference Reference previously marked by peer as missing.
    function removeMissingReferenceFlag(address _reference) public onlyPeer
    {
        LibSubmissionTrust.removeMissingReferenceFlag(trustData, _reference);
    }

    /// @dev Sets contributors and references at submission creation time
    /// @param _contribsAndRefs Struct containing contributors, reward distribution, and references
    function setContributorsAndReferences(LibConstruction.ContributorsAndReferences _contribsAndRefs) public // onlyOwner? add appropriate modifier
    {
        LibSubmission.setContributorsAndReferences(contributorsAndReferences, rewardData, trustData, _contribsAndRefs);
    }

    /// @dev Add a contributor to a submission (callable only by submission's owner).
    /// @param _contributor Address of contributor to add to the submission.
    function addContributor(address _contributor, uint128 _bountyAllocation) public onlyOwner
    {
        contributorsAndReferences.contributors.push(_contributor);

        rewardData.contributorToBountyDividend[_contributor] = _bountyAllocation;
        rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.add(_bountyAllocation);

        //IMatryxRound round = IMatryxRound(roundAddress);
    }

    function addContributors(address[] _contributorsToAdd, uint128[] _distribution) public onlyOwner
    {
        LibSubmission.addContributors(contributorsAndReferences, rewardData, _contributorsToAdd, _distribution);
    }

    /// @dev Remove a contributor from a submission (callable only by submission's owner).
    /// @param _contributorIndex Index of the contributor to remove from the submission.
    function removeContributor(uint256 _contributorIndex) onlyOwner public onlyOwner
    {
        rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.sub(rewardData.contributorToBountyDividend[contributorsAndReferences.contributors[_contributorIndex]]);
        rewardData.contributorToBountyDividend[contributorsAndReferences.contributors[_contributorIndex]] = 0;

        delete contributorsAndReferences.contributors[_contributorIndex];
    }

    function removeContributors(address[] _contributorsToRemove) public onlyOwner
    {
        for(uint32 i = 0; i < _contributorsToRemove.length; i++)
        {
            rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.sub(rewardData.contributorToBountyDividend[_contributorsToRemove[i]]);
            rewardData.contributorToBountyDividend[_contributorsToRemove[i]] = 0;
        }
    }

    function getBalance() public view returns (uint256)
    {
        IMatryxRound round = IMatryxRound(roundAddress);
        return round.getBalance(this);
    }

    function withdrawReward() public ownerContributorOrRound
    {
        LibSubmission.withdrawReward(platformAddress, contributorsAndReferences, rewardData, trustData);
    }

    function myReward() public view returns (uint256)
    {
        uint256 transferAmount = LibSubmission.getTransferAmount(platformAddress, rewardData, trustData);
        return LibSubmission._myReward(contributorsAndReferences, rewardData, msg.sender, transferAmount);
    }

}
