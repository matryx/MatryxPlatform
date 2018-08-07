pragma solidity ^0.4.18;

import '../libraries/math/SafeMath.sol';
import '../libraries/math/SafeMath128.sol';
import '../interfaces/IMatryxPlatform.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/IMatryxSubmission.sol';
import './Ownable.sol';

/// @title MatryxPeer - A peer within the MatryxPlatform.
/// @author Max Howard - <max@nanome.ai>
contract MatryxPeer is Ownable {
    using SafeMath for uint256;
    using SafeMath128 for uint128;

    uint128 one_eighteenDecimal = 1*10**18;

    // TODO: condense and put in structs
    address platformAddress;

    uint128 globalTrust;
    mapping(address=>uint128) judgedPeerToUnnormalizedTrust;
    mapping(address=>bool) haveJudgedPeer;
    address[] judgedPeers;

    uint128 totalTrustGiven;
    mapping(address=>uint128) judgingPeerToUnnormalizedTrust;
    mapping(address=>uint128) judgingPeerToTotalTrustGiven;

    mapping(address=>uint128) judgingPeerToInfluenceOnMyReputation;
    mapping(address=>bool) peerHasJudgedMe;
    address[] judgingPeers;

    //Keep track of how much trust/distrust was given when approving/flagging a submission
    mapping(address=>mapping(address=>uint128)) submissionToReferenceToTrustGiven;
    mapping(address=>mapping(address=>uint128)) submissionToReferenceToDistrustGiven;

    // Tracks the proportion of references this peer has approved on a given submission
    mapping(address=>uint256) submissionToApprovedReferences;
    mapping(address=>uint256) submissionToReferenceCount;
    mapping(address=>ReferencesMetadata) submissionToReferencesMetadata;

    event ReceivedReferenceRequest(address _submissionAddress, address reference);
    event ReferenceRequestCancelled(address _submissionAddress, address reference);

    /*
        * Structs
        */

    struct ReferencesMetadata
    {
        uint128 approvedReferenceCount;
        uint128 missingReferenceCount;
        uint128 totalReferenceCount;
    }

    /*
        * Modifiers
        */

    modifier onlyPlatform()
    {
        require(msg.sender == platformAddress);
        _;
    }

    modifier onlyPeer()
    {
        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        require(platform.isPeer(msg.sender));
        _;
    }

    // modifier notMe()
    // {
    // 	require(msg.sender != address(this));
    // 	_;
    // }

    // modifier notOwner()
    // {
    // 	require(msg.sender != owner);
    // 	_;
    // }

    modifier ownerOrSubmission(address _submission)
    {
        require((msg.sender == owner) || (msg.sender == _submission));
        _;
    }

    modifier forExistingSubmission(address _submission)
    {
        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        require(platform.isSubmission(_submission));
        _;
    }

    modifier senderOwnsReference(address _reference)
    {
        Ownable referencedSubmission = Ownable(_reference);
        address referenceOwner = referencedSubmission.getOwner();
        require(referenceOwner == msg.sender);
        _;
    }

    constructor(address _platformAddress, address _owner, uint128 _initialTrust) public
    {
        platformAddress = _platformAddress;
        owner = _owner;
        globalTrust = _initialTrust;
    }

    function getReputation() public view returns (uint128)
    {
        return globalTrust;
    }

    function giveTrust(address _peer) internal returns (uint128)
    {
        judgedPeerToUnnormalizedTrust[_peer] = judgedPeerToUnnormalizedTrust[_peer].add(one_eighteenDecimal);
        totalTrustGiven = totalTrustGiven.add(1);

        //if I have never judged this peer before, update structs to reflect that I have now
        if (haveJudgedPeer[_peer] == false){
            haveJudgedPeer[_peer] = true;
            judgedPeers.push(_peer);
        }

        return MatryxPeer(_peer).receiveTrust(totalTrustGiven, globalTrust);
    }

    function giveDistrust(address _peer) internal returns (uint128)
    {
        if(judgedPeerToUnnormalizedTrust[_peer] >= one_eighteenDecimal)
        {
            judgedPeerToUnnormalizedTrust[_peer] = judgedPeerToUnnormalizedTrust[_peer].sub(one_eighteenDecimal);
            totalTrustGiven = totalTrustGiven.sub(1);
        }

        //if I have never judged this peer before, update structs to reflect that I have now
        if (haveJudgedPeer[_peer] == false){
            haveJudgedPeer[_peer] = true;
            judgedPeers.push(_peer);
        }

        return MatryxPeer(_peer).receiveDistrust(totalTrustGiven, globalTrust);
    }

    function receiveTrust(uint128 _newTotalTrust, uint128 _senderReputation) public /*notMe notOwner*/ onlyPeer returns (uint128)
    {
        // remove peer's influence on my reputation before adding their new influence
        if(peerHasJudgedMe[msg.sender])
        {
            globalTrust = globalTrust.sub(judgingPeerToInfluenceOnMyReputation[msg.sender]);
        }
        // if we've never been judged by this peer before,
        // update state to reflect that we have now.
        else
        {
            peerHasJudgedMe[msg.sender] = true;
            judgingPeers.push(msg.sender);
        }

        // update state variables so we can look at them later
        uint128 peersOldInfluenceOnMyReputation = judgingPeerToInfluenceOnMyReputation[msg.sender];
        judgingPeerToUnnormalizedTrust[msg.sender] = judgingPeerToUnnormalizedTrust[msg.sender].add(one_eighteenDecimal);
        judgingPeerToTotalTrustGiven[msg.sender] = _newTotalTrust;
        // calculate peer's new influence on my reputation
        uint128 peersNewNormalizedOpinionOfMe = judgingPeerToUnnormalizedTrust[msg.sender].div(_newTotalTrust);
        uint128 peersNewInfluenceOnMyReputation = peersNewNormalizedOpinionOfMe.mul(_senderReputation);
        // _senderReputation and peersNewNormalizedOpinionOfMe are both 18 decimal numbers;
        // we must divide by 1*10**18 in order to retain the correct number of decimals.
        peersNewInfluenceOnMyReputation = peersNewInfluenceOnMyReputation.div(one_eighteenDecimal);
        judgingPeerToInfluenceOnMyReputation[msg.sender] = peersNewInfluenceOnMyReputation;
        // add this influence to my reputation
        globalTrust = globalTrust.add(peersNewInfluenceOnMyReputation);
        return uint128(peersNewInfluenceOnMyReputation.sub(peersOldInfluenceOnMyReputation));
    }

    function receiveDistrust(uint128 _newTotalTrust, uint128 _senderReputation) public /*notMe notOwner*/ onlyPeer returns (uint128)
    {
        uint128 peersOldInfluenceOnMyReputation = 0;
        // remove peer's influence on my reputation before adding their new influence
        if(peerHasJudgedMe[msg.sender])
        {
            //store the old influence on my reputation
            peersOldInfluenceOnMyReputation = judgingPeerToInfluenceOnMyReputation[msg.sender];
            globalTrust = globalTrust.sub(judgingPeerToInfluenceOnMyReputation[msg.sender]);
        }
        // if we've never been judged by this peer before,
        // update state to reflect that we have now.
        else
        {
            peerHasJudgedMe[msg.sender] = true;
            judgingPeers.push(msg.sender);
            //globalTrust = globalTrust.sub(one_eighteenDecimal);
        }

        //I don't have enough trust to be able to deduct some of it for having a submission flagged
        // if(judgingPeerToUnnormalizedTrust[msg.sender] < one_eighteenDecimal)
        // {
        // 	revert();
        // 	//return 0;
        // }

        //if the new total trust is zero, we don't have any new influence to add
        //so we update the data strustures and return
        if(_newTotalTrust == 0 || judgingPeerToUnnormalizedTrust[msg.sender] < one_eighteenDecimal)
        {
            judgingPeerToUnnormalizedTrust[msg.sender] = 0;
            judgingPeerToTotalTrustGiven[msg.sender] = 0;
            judgingPeerToInfluenceOnMyReputation[msg.sender] = 0;
            return uint128(peersOldInfluenceOnMyReputation);
        }

        judgingPeerToUnnormalizedTrust[msg.sender] = judgingPeerToUnnormalizedTrust[msg.sender].sub(one_eighteenDecimal);
        judgingPeerToTotalTrustGiven[msg.sender] = _newTotalTrust;
        // calculate peer's new influence on my reputation
        uint128 peersNewNormalizedOpinionOfMe = judgingPeerToUnnormalizedTrust[msg.sender].div(_newTotalTrust);
        uint128 peersNewInfluenceOnMyReputation = peersNewNormalizedOpinionOfMe.mul(_senderReputation);
        // _senderReputation and peersNewNormalizedOpinionOfMe are both 18 decimal numbers;
        // we must divide by 1*10**18 in order to retain the correct number of decimals.
        peersNewInfluenceOnMyReputation = peersNewInfluenceOnMyReputation.div(one_eighteenDecimal);
        judgingPeerToInfluenceOnMyReputation[msg.sender] = peersNewInfluenceOnMyReputation;
        // add this influence to my reputation
        globalTrust = globalTrust.add(peersNewInfluenceOnMyReputation);
        return uint128(peersOldInfluenceOnMyReputation.sub(peersNewInfluenceOnMyReputation));
    }

    function getPeersInfluenceOnMyReputation(address _peerAddress) public view returns (uint256)
    {
        return judgingPeerToInfluenceOnMyReputation[_peerAddress];
    }

    /// @dev 					  Flags a missing reference to a submission within another
    ///							  submission. This method should be called by the owner of
    /// 						  this peer in order to approve a reference to one of
    /// 	 					  their works within someone else's submission.
    /// @param _submissionAddress Address of the submission missing a reference.
    /// @param _missingReference  Reference that is missing.
    function flagMissingReference(address _submissionAddress, address _missingReference) public onlyOwner senderOwnsReference(_missingReference) forExistingSubmission(_submissionAddress) forExistingSubmission(_missingReference)
    {
        // Require that we're the author of the reference we're claiming is missing.
        // Require that the platform knows the submission.
        // Require that the platform knows the reference we're attempting to flag.

        // Add 1 to the state vars keeping track of the number of
        // this peer's submissions that _submission fails to reference
        // as well as the submission's total number of references to submissions by this peer
        submissionToReferencesMetadata[_submissionAddress].missingReferenceCount = submissionToReferencesMetadata[_submissionAddress].missingReferenceCount.add(1);

        IMatryxSubmission submission = IMatryxSubmission(_submissionAddress);
        submission.flagMissingReference(_missingReference);

        address submissionAuthor = submission.getAuthor();
        submissionToReferenceToDistrustGiven[_submissionAddress][_missingReference] = giveDistrust(submissionAuthor);
    }

    function getMissingReferenceCount(address _submissionAddress) public view returns (uint128, uint128)
    {
        return (submissionToReferencesMetadata[_submissionAddress].missingReferenceCount, submissionToReferencesMetadata[_submissionAddress].totalReferenceCount);
    }

    /// @dev					  Removes a flag on a missing reference from a submission.
    /// @param _submissionAddress Address of the submission which was previously flagged as missing a reference
    ///							  to this peer's work.
    /// @param _missingReference  Address of the reference to vindicate.
    function removeMissingReferenceFlag(address _submissionAddress, address _missingReference) public ownerOrSubmission(_submissionAddress) forExistingSubmission(_submissionAddress) forExistingSubmission(_missingReference)
    {
        // Require that the platform knows the submission.
        // Require that the platform knows the reference we'd like to vindicate.
        // Require that we're the author of the reference we're attempting to vindicate
        // Require that we've flagged the submission before.
        //require(submissionToReferenceToDistrustGiven[_submissionAddress][_missingReference] > 0);

        submissionToReferencesMetadata[_submissionAddress].missingReferenceCount = submissionToReferencesMetadata[_submissionAddress].missingReferenceCount.sub(1);
        totalTrustGiven = totalTrustGiven.add(1);

        IMatryxSubmission submission = IMatryxSubmission(_submissionAddress);
        submission.removeMissingReferenceFlag(_missingReference);

        address submissionAuthor = submission.getAuthor();

        judgedPeerToUnnormalizedTrust[submissionAuthor] = judgedPeerToUnnormalizedTrust[submissionAuthor].add(one_eighteenDecimal);

        MatryxPeer(submissionAuthor).restoreTrust(submissionToReferenceToDistrustGiven[_submissionAddress][_missingReference]);

        //clean up previous distrust given
        submissionToReferenceToDistrustGiven[_submissionAddress][_missingReference] = 0;
    }

    function restoreTrust(uint128 _trustRemoved) public
    {
        //restore the trust that was taken away upon flagging the submission
        judgingPeerToUnnormalizedTrust[msg.sender] = judgingPeerToUnnormalizedTrust[msg.sender].add(one_eighteenDecimal);
        judgingPeerToTotalTrustGiven[msg.sender] = judgingPeerToTotalTrustGiven[msg.sender].add(_trustRemoved);
        judgingPeerToInfluenceOnMyReputation[msg.sender] = judgingPeerToInfluenceOnMyReputation[msg.sender].add(_trustRemoved);

        globalTrust = globalTrust.add(_trustRemoved);
    }

    /// @dev 					  Approve of a reference to a submission written by this peer
    /// 						  on another submission. This method should be called by the
    /// 	 					  owner of this peer in order to approve a reference to one
    /// 	 					  of their works within someone else's submission.
    /// @param _submissionAddress Address of the submission on which to approve the reference.
    /// @param _reference 		  Reference to approve.
    function approveReference(address _submissionAddress, address _reference) public onlyOwner senderOwnsReference(_reference) forExistingSubmission(_submissionAddress) forExistingSubmission(_reference)
    {
        // Require that we're the author of the reference we're attempting to approve
        // Require that the platform knows the submission.
        // Require that the platform knows the reference we'd like to approve.

        // Add 1 to the state var keeping track of the number of approved references on this submission
        submissionToReferencesMetadata[_submissionAddress].approvedReferenceCount = submissionToReferencesMetadata[_submissionAddress].approvedReferenceCount.add(1);

        IMatryxSubmission submission = IMatryxSubmission(_submissionAddress);
        submission.approveReference(_reference);

        address submissionAuthor = submission.getAuthor();
        submissionToReferenceToTrustGiven[_submissionAddress][_reference] = giveTrust(submissionAuthor);
    }

    /// @dev 					  Remove approval of a reference from a submission.
    /// @param _submissionAddress Address of the submission which was previously given an approval
    /// 						  for one of its references.
    /// @param _reference 		  Address of the reference to decry.
    function removeReferenceApproval(address _submissionAddress, address _reference) public ownerOrSubmission(_submissionAddress) forExistingSubmission(_submissionAddress) forExistingSubmission(_reference)
    {
        // Require that the platform knows the submission.
        // Require that the platform knows the reference we'd like to decry.
        // Require that we're the author of the reference we're attempting to decry.
        // Require that we have approvel the reference before
        //require(submissionToReferenceToTrustGiven[_submissionAddress][_reference] > 0);

        // Remove 1 from the state var keeping track of the number of approved references on this submission
        submissionToReferencesMetadata[_submissionAddress].approvedReferenceCount = submissionToReferencesMetadata[_submissionAddress].approvedReferenceCount.sub(1);
        totalTrustGiven = totalTrustGiven.sub(1);

        IMatryxSubmission submission = IMatryxSubmission(_submissionAddress);
        submission.removeReferenceApproval(_reference);

        address submissionAuthor = submission.getAuthor();

        //revoke the trust that was given upon approving the submission
        judgedPeerToUnnormalizedTrust[submissionAuthor] = judgedPeerToUnnormalizedTrust[submissionAuthor].add(one_eighteenDecimal);

        MatryxPeer(submissionAuthor).revokeTrust(submissionToReferenceToTrustGiven[_submissionAddress][_reference]);

        //clean up previous trust given
        submissionToReferenceToTrustGiven[_submissionAddress][_reference] = 0;
    }

    function revokeTrust(uint128 _trustGiven) public
    {
        //revoke the trust that was given upon approving the submission
        judgingPeerToUnnormalizedTrust[msg.sender] = judgingPeerToUnnormalizedTrust[msg.sender].sub(one_eighteenDecimal);
        //judgingPeerToTotalTrustGiven[msg.sender] = judgingPeerToTotalTrustGiven[msg.sender].sub(_trustGiven);
        //judgingPeerToInfluenceOnMyReputation[msg.sender] = judgingPeerToInfluenceOnMyReputation[msg.sender].sub(_trustGiven);

        globalTrust = globalTrust.sub(_trustGiven);
    }

    function getApprovedAndTotalReferenceCounts(address _submissionAddress) public view returns (uint128, uint128)
    {
        return (submissionToReferencesMetadata[_submissionAddress].approvedReferenceCount, submissionToReferencesMetadata[_submissionAddress].totalReferenceCount);
    }

    function getApprovedReferenceProportion(address _submissionAddress) public view returns (uint128)
    {
        if(submissionToReferencesMetadata[_submissionAddress].totalReferenceCount + submissionToReferencesMetadata[_submissionAddress].missingReferenceCount == 0)
        {
            return 0;
        }

        return submissionToReferencesMetadata[_submissionAddress].approvedReferenceCount.div(submissionToReferencesMetadata[_submissionAddress].totalReferenceCount.add(submissionToReferencesMetadata[_submissionAddress].missingReferenceCount));
    }

    function peersJudged() public view returns (uint256)
    {
        return judgedPeers.length;
    }

    function getJudgingPeerToUnnormalizedTrust(address _peer) public view returns (uint128)
    {
        return judgingPeerToUnnormalizedTrust[_peer];
    }

    // function normalizedTrustInPeer(address _peer) public onlyOwner view returns (uint128)
    // {
    // 	uint128 normalizedTrust = judgedPeerToUnnormalizedTrust[_peer].div(totalTrustGiven);
    // 	if(normalizedTrust > 0)
    // 	{
    // 		return normalizedTrust;
    // 	}

    // 	return 0;
    // }
}
