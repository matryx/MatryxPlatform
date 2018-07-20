pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;


import "../libraries/math/SafeMath.sol";
import "../libraries/math/SafeMath128.sol";
import "../libraries/strings/strings.sol";
import "../libraries/LibConstruction.sol";
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

    // constructor(address[3] requiredAddresses, LibConstruction.SubmissionData submissionData) public
    // constructor(address _owner) public
    constructor(address _owner, LibConstruction.SubmissionData submissionData) public
    {
        // platformAddress = requiredAddresses.platformAddress;
        // tournamentAddress = requiredAddresses.tournamentAddress;
        // roundAddress = requiredAddresses.roundAddress;

        // platformAddress = requiredAddresses[0];
        // tournamentAddress = requiredAddresses[1];
        // roundAddress = requiredAddresses[2];

        // data = submissionData;
        // author = IMatryxPlatform(platformAddress).peerAddress(_owner);
        // require(author != 0x0);

        // for(uint32 i = 0; i < data.references.length;i++)
        // {
        //     trustData.addressToReferenceInfo[data.references[i]].exists = true;
        //     trustData.addressToReferenceInfo[data.references[i]].index = i;
        // }

        // LibSubmission.addContributors(rewardData, submissionData.contributors, submissionData.contributorRewardDistribution);

        // data.timeSubmitted = now;
        // data.timeUpdated = now;
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

    modifier duringOpenSubmission()
    {
        require(IMatryxRound(roundAddress).getState() == 1);
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
        bool roundAtLeastInReview = IMatryxRound(roundAddress).getState() >= 2;
        bool requesterIsEntrant = IMatryxTournament(tournamentAddress).isEntrant(_requester);
        bool requesterOwnsTournament = ownableTournament.getOwner() == _requester;
        bool duringReviewAndRequesterInTournament = roundAtLeastInReview && (requesterOwnsTournament || requesterIsEntrant);
        // TODO: think about next steps (encryption)
        bool roundIsClosed = IMatryxRound(roundAddress).getState() >= 5;

        return isPlatform || isRound || ownsThisSubmission || duringReviewAndRequesterInTournament || IMatryxPlatform(platformAddress).isPeer(_requester) || IMatryxPlatform(platformAddress).isSubmission(_requester) || roundIsClosed;
    }

    function getTitle() public view whenAccessible(msg.sender) returns(string) {
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

    function update(LibConstruction.SubmissionModificationData _modificationData, LibConstruction.ContributorsModificationData _contributorsModificationData, LibConstruction.ReferencesModificationData _referencesModificationData) public
    {
        LibSubmission.update(data, rewardData, _modificationData, _contributorsModificationData, _referencesModificationData);
    }

    /// @dev Edit the title of a submission (callable only by submission's owner).
    /// @param _title New title for the submission.
    function updateTitle(string _title) public onlyOwner duringOpenSubmission
    {
        data.title = _title;
        data.timeUpdated = now;
    }

    /// @dev Update the description hash of the submission (callable only by submission's owner).
    /// @param _descriptionHash New hash for the description of the submission.
    function updateDescription(bytes32[2] _descriptionHash) public onlyOwner duringOpenSubmission
    {
        data.descriptionHash = _descriptionHash;
        data.timeUpdated = now;
    }

    /// @dev Update the file hash of the submission (callable only by submission's owner).
    /// @param _fileHash New hash for the body of the submission
    function updateFile(bytes32[2] _fileHash) public onlyOwner duringOpenSubmission
    {
        data.fileHash = _fileHash;
        data.timeUpdated = now;
    }

    function addToWinnings(uint256 _amount) public onlySubmissionOrRound
    {
        rewardData.winnings = rewardData.winnings.add(_amount);
    }

    /// @dev Add a missing reference to a submission (callable only by submission's owner).
    /// @param _reference Address of additional reference to include.

    function addReference(address _reference) onlyOwner public
    {
        LibSubmissionTrust.addReference(contributorsAndReferences, trustData, _reference, platformAddress);
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
        LibSubmissionTrust.removeReference(contributorsAndReferences, trustData, _reference, platformAddress);
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

        IMatryxRound round = IMatryxRound(roundAddress);
        round.setParticipantType(_contributor, 2);
    }

    function addContributors(address[] _contributorsToAdd, uint128[] _distribution) public onlyOwner
    {
        LibSubmission.addContributors(rewardData, _contributorsToAdd, _distribution);
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
        for(uint32 j = 0; j < _contributorsToRemove.length; j++)
        {
            rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.sub(rewardData.contributorToBountyDividend[_contributorsToRemove[j]]);
            rewardData.contributorToBountyDividend[_contributorsToRemove[j]] = 0;
        }
    }

    function getBalance() public returns (uint256)
    {
        IMatryxRound round = IMatryxRound(roundAddress);
        uint256 _balance = round.getBalance(this);
        return _balance;
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
