pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../math/SafeMath.sol";
import "./LibTournamentStateManagement.sol";
import "../../interfaces/IMatryxToken.sol";
import "../../interfaces/IMatryxPlatform.sol";
import "../../interfaces/IMatryxTournament.sol";

library LibTournamentEntrantMethods
{
    using SafeMath for uint256;

    enum TournamentState { NotYetOpen, OnHold, Open, Closed, Abandoned}
    enum ParticipantType { Nonentrant, Entrant, Contributor, Author }

    struct uint256_optional
    {
        bool exists;
        uint256 value;
    }

    /// @dev Enters the user into the tournament.
    /// @param _entrantAddress Address of the user to enter.
    /// @return success Whether or not the user was entered successfully.
    function enterUserInTournament(LibConstruction.TournamentData storage data, LibTournamentStateManagement.StateData storage stateData, LibTournamentStateManagement.EntryData storage entryData, address _entrantAddress) public returns (bool _success)
    {
        if(entryData.addressToEntryFeePaid[_entrantAddress].exists == true)
        {
            return false;
        }

        // Change the tournament's state to reflect the user entering.
        entryData.addressToEntryFeePaid[_entrantAddress].exists = true;
        entryData.addressToEntryFeePaid[_entrantAddress].value = data.entryFee;
        stateData.entryFeesTotal = stateData.entryFeesTotal.add(data.entryFee);
        entryData.numberOfEntrants = entryData.numberOfEntrants.add(1);

        (, address currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        IMatryxRound(currentRoundAddress).becomeEntrant(_entrantAddress);

        return true;
    }

    /// @dev Returns the fee in MTX to be payed by a prospective entrant.
    /// @return Entry fee for this tournament.
    function getEntryFee(LibConstruction.TournamentData data) public view returns (uint256)
    {
        return data.entryFee;
    }

    function collectMyEntryFee(LibTournamentStateManagement.StateData storage stateData, LibTournamentStateManagement.EntryData storage entryData, address matryxTokenAddress) public
    {
        returnEntryFeeToEntrant(stateData, entryData, msg.sender, matryxTokenAddress);
    }

    function returnEntryFeeToEntrant(LibTournamentStateManagement.StateData storage stateData, LibTournamentStateManagement.EntryData storage entryData, address _entrant, address matryxTokenAddress) internal
    {
        // Make sure entrants don't withdraw their entry fee early
        uint256 currentState = LibTournamentStateManagement.getState(stateData);
        (,address currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        require(IMatryxRound(currentRoundAddress).getParticipantType(_entrant) == uint256(ParticipantType.Entrant));

        IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
        require(matryxToken.transfer(_entrant, entryData.addressToEntryFeePaid[_entrant].value));
        stateData.entryFeesTotal = stateData.entryFeesTotal.sub(entryData.addressToEntryFeePaid[_entrant].value);
        entryData.addressToEntryFeePaid[_entrant].exists = false;
        entryData.addressToEntryFeePaid[_entrant].value = 0;
        entryData.numberOfEntrants = entryData.numberOfEntrants.sub(1);
        IMatryxRound(currentRoundAddress).becomeNonentrant(_entrant);
    }

    function createSubmission(LibTournamentStateManagement.StateData storage stateData, LibTournamentStateManagement.EntryData storage entryData, address platformAddress, address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress)
    {
        address currentRoundAddress;
        (, currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        address submissionAddress = IMatryxRound(currentRoundAddress).createSubmission(_contributors, _contributorRewardDistribution, _references, IMatryxPlatform(platformAddress).peerAddress(submissionData.owner), submissionData);
        // Send out reference requests to the authors of other submissions
        IMatryxPlatform(platformAddress).handleReferenceRequestsForSubmission(submissionAddress, _references);

        entryData.numberOfSubmissions = entryData.numberOfSubmissions.add(1);
        entryData.entrantToSubmissionToSubmissionIndex[msg.sender][submissionAddress].exists = true;
        entryData.entrantToSubmissionToSubmissionIndex[msg.sender][submissionAddress].value = entryData.entrantToSubmissions[msg.sender].length;
        entryData.entrantToSubmissions[msg.sender].push(submissionAddress);
        IMatryxPlatform(platformAddress).updateSubmissions(msg.sender, submissionAddress);
        
        return submissionAddress;
    }

    function withdrawFromAbandoned(LibTournamentStateManagement.StateData storage stateData, LibTournamentStateManagement.EntryData storage entryData, address matryxTokenAddress) public
    {
        require(LibTournamentStateManagement.getState(stateData) == uint256(TournamentState.Abandoned), "This tournament is still valid.");
        require(!entryData.hasWithdrawn[msg.sender]);

        address currentRoundAddress;
        (, currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        uint256 numberOfEntrants = entryData.numberOfEntrants;
        uint256 bounty = IMatryxTournament(this).getBounty();
        // If this is the first withdrawal being made...
        if(IMatryxToken(matryxTokenAddress).balanceOf(currentRoundAddress) > 0)
        {
            uint256 roundBounty = IMatryxRound(currentRoundAddress).transferBountyToTournament();
            stateData.roundBountyAllocation = stateData.roundBountyAllocation.sub(roundBounty);
            returnEntryFeeToEntrant(stateData, entryData, msg.sender, matryxTokenAddress);
            require(IMatryxToken(matryxTokenAddress).transfer(msg.sender, bounty.div(entryData.numberOfEntrants).mul(2)));
        }
        else
        {
            returnEntryFeeToEntrant(stateData, entryData, msg.sender, matryxTokenAddress);
            require(IMatryxToken(matryxTokenAddress).transfer(msg.sender, bounty.mul(numberOfEntrants.sub(2)).div(numberOfEntrants).div(numberOfEntrants.sub(1))));
        }

        entryData.hasWithdrawn[msg.sender] = true;
    }
}