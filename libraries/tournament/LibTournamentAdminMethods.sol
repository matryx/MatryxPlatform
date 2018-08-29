pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../math/SafeMath.sol";
import "../strings/strings.sol";
import "../../interfaces/factories/IMatryxRoundFactory.sol";
import "./LibTournamentStateManagement.sol";
import "../LibEnums.sol";
import "../../interfaces/IMatryxPlatform.sol";
import "../../interfaces/IMatryxToken.sol";
import "../../interfaces/IMatryxTournament.sol";
import "../../interfaces/IMatryxRound.sol";

library LibTournamentAdminMethods
{
    using SafeMath for uint256;
    using strings for *;

    event RoundWinnersChosen(address[] _submissionAddresses);
    event NewRound(uint256 start, uint256 end, uint256 ReviewPeriodDuration, address roundAddress, uint256 roundNumber);

    function update(LibConstruction.TournamentData storage self, LibConstruction.TournamentModificationData tournamentData, address platformAddress) public
    {
        // TODO: Update the category on the platform
        if(tournamentData.category != 0x0)
        {
            IMatryxPlatform(platformAddress).updateTournamentCategory(address(this), self.category, tournamentData.category);
            self.category = tournamentData.category;
        }
        if(tournamentData.title[0] != 0x0)
        {
            self.title = tournamentData.title;
        }
        if(tournamentData.descriptionHash[0] != 0x0)
        {
            self.descriptionHash = tournamentData.descriptionHash;
        }
        if(tournamentData.fileHash[0] != 0x0)
        {
            self.fileHash = tournamentData.fileHash;
        }
        if(tournamentData.entryFeeChanged)
        {
            self.entryFee = tournamentData.entryFee;
        }
    }

    /// @dev Chooses the winner(s) of the current round.
    /// @param stateData State data for the tournament
    /// @param _selectWinnersData Struct containing winning submission information
    function selectWinners(LibTournamentStateManagement.StateData storage stateData, address platformAddress, address matryxTokenAddress, LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public
    {
        // Round must be in review
        (,address currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        uint256 roundState = uint256(IMatryxRound(currentRoundAddress).getState());
        require(roundState == uint256(LibEnums.RoundState.InReview), "Round is not in review.");

        // Event to notify web3 of the winning submission address
        emit RoundWinnersChosen(_selectWinnersData.winningSubmissions);
        IMatryxRound(currentRoundAddress).selectWinningSubmissions(_selectWinnersData, _roundData);

        // Close the tournament if the tournament owner chooses to
        if(_selectWinnersData.selectWinnerAction == uint256(LibEnums.SelectWinnerAction.CloseTournament))
        {
            uint256 remainingBalance = IMatryxTournament(this).getBalance();
            closeTournament(stateData, platformAddress, matryxTokenAddress, remainingBalance, currentRoundAddress);
        }
    }

    /// @dev Edits the next round that is created during the previous round's ChooseWinningSubmissions
    /// @param stateData State data for the tournament (see above)
    /// @param _roundData Incoming new round data
    function editGhostRound(LibTournamentStateManagement.StateData storage stateData, LibConstruction.RoundData _roundData, address matryxTokenAddress) public
    {
        (uint256 ghostRoundIndex, address ghostRoundAddress) = LibTournamentStateManagement.getGhostRound(stateData);
        if(ghostRoundAddress != 0x0)
        {
            uint256 ghostRoundBounty = IMatryxRound(ghostRoundAddress).getBounty();
            if(_roundData.bounty > ghostRoundBounty)
            {
                // Transfer to ghost round
                uint256 addAmount = _roundData.bounty.sub(ghostRoundBounty);
                stateData.roundBountyAllocation = stateData.roundBountyAllocation.add(addAmount);
                require(IMatryxToken(matryxTokenAddress).transfer(ghostRoundAddress, addAmount));
            }

            else if(_roundData.bounty < ghostRoundBounty)
            {
                // Have ghost round transfer to the tournament
                uint256 subAmount = ghostRoundBounty.sub(_roundData.bounty);
                stateData.roundBountyAllocation = stateData.roundBountyAllocation.sub(subAmount);
                IMatryxRound(ghostRoundAddress).transferToTournament(subAmount);
            }

            IMatryxRound(ghostRoundAddress).editRound(IMatryxRound(stateData.rounds[ghostRoundIndex-1]).getEndTime(), _roundData);
        }
    }

    ///@dev Allocates some of this tournament's balance to the current round
    function allocateMoreToRound(LibTournamentStateManagement.StateData storage stateData, uint256 _mtxAllocation, address matryxTokenAddress) public
    {
        require(_mtxAllocation <= IMatryxTournament(this).getBalance());

        (, address currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        uint256 currentRoundState = IMatryxRound(currentRoundAddress).getState();
        require(
            currentRoundState == uint256(LibEnums.RoundState.NotYetOpen) ||
            currentRoundState == uint256(LibEnums.RoundState.Unfunded) ||
            currentRoundState == uint256(LibEnums.RoundState.Open));

        stateData.roundBountyAllocation = stateData.roundBountyAllocation.add(_mtxAllocation);
        require(IMatryxToken(matryxTokenAddress).transfer(currentRoundAddress, _mtxAllocation));
        IMatryxRound(currentRoundAddress).addBounty(_mtxAllocation);
    }

    /// @dev This function should be called after the user selects winners for their tournament and chooses the "Start Next Round" option
    function jumpToNextRound(LibTournamentStateManagement.StateData storage stateData) public
    {
        (uint256 currentRoundIndex, address currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        IMatryxRound(stateData.rounds[currentRoundIndex.add(1)]).startNow();
    }

    /// @dev Chooses the winner of the tournament.
    function closeTournament(LibTournamentStateManagement.StateData storage stateData, address platformAddress, address matryxTokenAddress, uint256 remainingBalance, address currentRoundAddress) internal
    {
        require(IMatryxRound(currentRoundAddress).getState() == uint256(LibEnums.RoundState.Closed));
        // Transfer the remaining MTX in the tournament to the current round
        stateData.roundBountyAllocation = stateData.roundBountyAllocation.add(remainingBalance);
        require(IMatryxToken(matryxTokenAddress).transfer(currentRoundAddress, remainingBalance));
        IMatryxRound(currentRoundAddress).transferAllToWinners(remainingBalance);
        IMatryxPlatform(platformAddress).invokeTournamentClosedEvent(stateData.rounds.length, IMatryxRound(currentRoundAddress).getBounty());

        stateData.closed = true;
    }

    /// @dev Sends tournament funds back to the owner if the tournament goes to Abandoned due to no submissions
    function recoverFunds(LibTournamentStateManagement.StateData storage stateData, address matryxTokenAddress) public
    {
        // Get current round
        address currentRoundAddress;
        (, currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        require(IMatryxRound(currentRoundAddress).numberOfSubmissions() == 0);

        // Transfer the round funds to the tournament
        IMatryxRound(currentRoundAddress).transferBountyToTournament();

        // Transfer all tournament funds to the owner
        uint256 tBalance = IMatryxTournament(this).getBalance();
        require(IMatryxToken(matryxTokenAddress).transfer(msg.sender, tBalance));

        // Bookkeeping
        stateData.hasBeenWithdrawnFrom = true;
        stateData.closed = true;
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(LibTournamentStateManagement.StateData storage stateData, address platformAddress, address matryxTokenAddress, address matryxRoundFactoryAddress, LibConstruction.RoundData roundData, bool _automaticCreation) public returns (address _roundAddress)
    {
        // Only this, the tournamentFactory or rounds can call createRound
        require(msg.sender == address(this) || msg.sender == IMatryxPlatform(platformAddress).getTournamentFactoryAddress() || stateData.isRound[msg.sender]);
        require(roundData.start < roundData.end, "Time parameters are invalid.");

        // Rounds that are not created automatically must have a valid bounty
        if(_automaticCreation == false)
        {
            require(IMatryxTournament(this).getBalance() >= roundData.bounty && roundData.bounty > 0);
        }

        // Argument for start & duration instead of start & end
        if(roundData.start < now)
        {
            uint256 duration = roundData.end.sub(roundData.start);
            roundData.start = now;
            roundData.end = now.add(duration);
        }

        IMatryxRoundFactory roundFactory = IMatryxRoundFactory(matryxRoundFactoryAddress);
        address newRoundAddress = roundFactory.createRound(platformAddress, this, roundData);

        // Transfer the round bounty to the round.
        // If this is the first round, the bounty is transfered to the round *by the platform in createTournament* (by tournament.sendBountyToRound)
        if(stateData.rounds.length != 0 && roundData.bounty != 0)
        {
            stateData.roundBountyAllocation = stateData.roundBountyAllocation.add(roundData.bounty);
            IMatryxToken(matryxTokenAddress).transfer(newRoundAddress, roundData.bounty);
        }

        stateData.rounds.push(newRoundAddress);
        stateData.isRound[newRoundAddress] = true;

        // Triggers Event displaying start time, end, address, and round number
        emit NewRound(roundData.start, roundData.end, roundData.reviewPeriodDuration, newRoundAddress, stateData.rounds.length);

        return newRoundAddress;
    }
}
