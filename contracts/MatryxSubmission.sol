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
    LibConstruction.ContributorsAndReferences contributorsAndReferences;
    LibSubmission.RewardData rewardData;
    LibSubmission.TrustData trustData;
    LibSubmission.FileDownloadTracking downloadData;

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

        downloadData.permittedToViewFile[_owner] = true;
        downloadData.permittedToViewFile[Ownable(tournamentAddress).getOwner()] = true;
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

    modifier onlyTournament() {
        require(msg.sender == tournamentAddress);
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

    modifier onlyHasPeer() {
        require(IMatryxPlatform(platformAddress).hasPeer(msg.sender));
        _;
    }

    modifier atLeastInReview() {
        require(IMatryxRound(roundAddress).getState() >= uint256(LibEnums.RoundState.InReview));
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

    function getData() public view whenAccessible(msg.sender) returns(LibConstruction.SubmissionData _data) {
        LibConstruction.SubmissionData memory returnData = data;

        if(!downloadData.permittedToViewFile[msg.sender])
        {
            returnData.fileHash[0] = 0x0;
            returnData.fileHash[1] = 0x0;
        }

        return returnData;
    }

    function getTitle() public view whenAccessible(msg.sender) returns(bytes32[3]) {
        return data.title;
    }

    function getAuthor() public view whenAccessible(msg.sender) returns(address) {
        return author;
    }

    function getDescriptionHash() public view whenAccessible(msg.sender) returns (bytes32[2]) {
        return data.descriptionHash;
    }

    function getFileHash() public view whenAccessible(msg.sender) returns (bytes32[2]) {
        require(downloadData.permittedToViewFile[msg.sender]);
        return data.fileHash;
    }

    function getPermittedDownloaders() public view returns (address[]) {
        return downloadData.allPermittedToViewFile;
    }

    function getReferences() public view whenAccessible(msg.sender) returns(address[]) {
        return contributorsAndReferences.references;
    }

    function getContributors() public view whenAccessible(msg.sender) returns(address[]) {
        return contributorsAndReferences.contributors;
    }

    function getContributorRewardDistribution() public view whenAccessible(msg.sender) returns (uint256[]) {
        assembly {
            let ptr := mload(0x40)
            let len := sload(contributorsAndReferences_slot)

            mstore(ptr, 0x20)           // elem size
            mstore(add(ptr, 0x20), len) // arr len

            mstore(0, contributorsAndReferences_slot)
            let s_car := keccak256(0, 0x20)

            mstore(0x20, add(rewardData_slot, 3)) // rewardData.contributorToBountyDividend

            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                let con := sload(add(s_car, i))
                mstore(0, con)
                let dist := keccak256(0, 0x40)    // rewardData.contributorToBountyDividend[contributor]
                mstore(add(ptr, mul(add(i, 2), 0x20)), sload(dist))
            }

            return(ptr, mul(add(len, 2), 0x20))
        }
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

    function unlockFile() public onlyHasPeer atLeastInReview {
        downloadData.permittedToViewFile[msg.sender] = true;
        downloadData.allPermittedToViewFile.push(msg.sender);
    }

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

    // // Debug function. ?MAYBEDO:Delete
    // function addressIsFlagged(address _reference) public view returns (bool, bool)
    // {
    // 	return (addressToReferenceInfo[_reference].flagged, missingReferenceToIndex[_reference].exists);
    // }

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
    function setContributorsAndReferences(LibConstruction.ContributorsAndReferences _contribsAndRefs) public onlyTournament
    {
        LibSubmission.setContributorsAndReferences(contributorsAndReferences, rewardData, trustData, downloadData, _contribsAndRefs);
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
