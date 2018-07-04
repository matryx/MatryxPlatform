pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../math/SafeMath.sol";
import "../strings/strings.sol";
import "../../interfaces/factories/IMatryxRoundFactory.sol";
import "./LibTournamentStateManagement.sol";
import "../../interfaces/IMatryxPlatform.sol";
import "../../interfaces/IMatryxToken.sol";
import "../../interfaces/IMatryxTournament.sol";
import "../../interfaces/IMatryxRound.sol";

library LibTournamentAdminMethods
{
    using SafeMath for uint256;
    using strings for *;

    enum RoundState { NotYetOpen, Unfunded, Open, InReview, HasWinners, Closed, Abandoned }
    enum SelectWinnerAction { DoNothing, StartNextRound, CloseTournament }

    event NewRound(uint256 _startTime, uint256 _endTime, uint256 _reviewPeriodDuration, address _roundAddress, uint256 _roundNumber);
    event RoundWinnersChosen(address[] _submissionAddresses);

    function update(LibConstruction.TournamentData storage self, LibConstruction.TournamentModificationData tournamentData, string _category, address platformAddress)
    {
        // TODO: Update the category on the platform
        if(_category.toSlice().empty() == false)
        {
            IMatryxPlatform(platformAddress).switchTournamentCategory(address(this), self.category, _category);
            self.category = _category;
        }
        if(tournamentData.title_1 != 0x0)
        {
            self.title_1 = tournamentData.title_1;
            self.title_2 = tournamentData.title_2;
            self.title_2 = tournamentData.title_3;
        }
        if(tournamentData.descriptionHash_1 != 0x0)
        {
            self.descriptionHash_1 = tournamentData.descriptionHash_1;
            self.descriptionHash_2 = tournamentData.descriptionHash_2;
        }
        if(tournamentData.fileHash_1 != 0x0)
        {
            self.fileHash_1 = tournamentData.fileHash_1;
            self.fileHash_2 = tournamentData.fileHash_2;
        }
        if(tournamentData.entryFeeChanged)
        {
            self.entryFee = tournamentData.entryFee;
        }
    }

    /// @dev Chooses the winner(s) of the current round. If this is the last round, 
    //       this method will also close the tournament.
    /// @param _submissionAddresses The winning submission addresses
    /// @param _rewardDistribution Distribution indicating how to split the reward among the submissions
    function selectWinners(LibTournamentStateManagement.StateData storage stateData, address platformAddress, address matryxTokenAddress, address[] _submissionAddresses, uint256[] _rewardDistribution, LibConstruction.RoundData _roundData, uint256 _selectWinnerAction) public
    {
        // Round must be in review or have winners to close
        (,address currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        uint256 roundState = uint256(IMatryxRound(currentRoundAddress).getState());
        require(roundState == uint256(RoundState.InReview) || roundState == uint256(RoundState.HasWinners), "Round is not in review or winners have not been chosen.");
        uint256 remainingBalance = IMatryxTournament(this).getBalance();
        // Event to notify web3 of the winning submission address
        emit RoundWinnersChosen(_submissionAddresses);
        IMatryxRound(currentRoundAddress).selectWinningSubmissions(_submissionAddresses, _rewardDistribution, _roundData, _selectWinnerAction);
        // if(_selectWinnerAction == uint256(SelectWinnerAction.CloseTournament))
        // {
        //     closeTournament(stateData, platformAddress, matryxTokenAddress, remainingBalance, currentRoundAddress);
        // }
    }

    function editGhostRound(LibTournamentStateManagement.StateData storage stateData, LibConstruction.RoundData _roundData, address matryxTokenAddress) public
    {

        (uint256 ghostRoundIndex, address ghostRoundAddress) = LibTournamentStateManagement.getGhostRound(stateData);
        (,address currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
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
        (, address currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        uint256 currentRoundState = IMatryxRound(currentRoundAddress).getState();
        require(currentRoundState == uint256(RoundState.NotYetOpen) || 
                currentRoundState == uint256(RoundState.Unfunded) || 
                currentRoundState == uint256(RoundState.Open));

        stateData.roundBountyAllocation = stateData.roundBountyAllocation.add(_mtxAllocation);
        require(IMatryxToken(matryxTokenAddress).transfer(currentRoundAddress, _mtxAllocation));
    }

    /// @dev This function should be called after the user selects winners for their tournament and chooses the "DoNothing" option
    function jumpToNextRound(LibTournamentStateManagement.StateData storage stateData) public
    {
        (uint256 currentRoundIndex, address currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        IMatryxRound(currentRoundAddress).closeRound();
        IMatryxRound(stateData.rounds[currentRoundIndex+1]).startNow();
    }

    /// @dev This function closes the tournament after the tournament owner selects their winners with the "DoNothing" option
    function stopTournament(LibTournamentStateManagement.StateData storage stateData, address platformAddress, address matryxTokenAddress) public
    {
        uint256 remainingBalance = IMatryxTournament(this).getBalance();
        (,address currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        IMatryxRound(currentRoundAddress).closeRound();
        closeTournament(stateData, platformAddress, matryxTokenAddress, remainingBalance, currentRoundAddress);
    }

    // @dev Chooses the winner of the tournament.
    function closeTournament(LibTournamentStateManagement.StateData storage stateData, address platformAddress, address matryxTokenAddress, uint256 remainingBalance, address currentRoundAddress) public
    {
        uint256 roundState = uint256(IMatryxRound(currentRoundAddress).getState());
        require(IMatryxRound(currentRoundAddress).getState() == uint256(RoundState.HasWinners));
        // Transfer the remaining MTX in the tournament to the current round
        stateData.roundBountyAllocation = stateData.roundBountyAllocation.add(remainingBalance);
        IMatryxToken(matryxTokenAddress).transfer(currentRoundAddress, remainingBalance);
        IMatryxRound(currentRoundAddress).transferAllToWinners(remainingBalance);
        IMatryxPlatform(platformAddress).invokeTournamentClosedEvent(stateData.rounds.length, IMatryxRound(currentRoundAddress).getBounty());
            
        stateData.closed = true;
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(LibTournamentStateManagement.StateData storage stateData, address platformAddress, address matryxTokenAddress, address matryxRoundFactoryAddress, LibConstruction.RoundData roundData, bool _automaticCreation) public returns (address _roundAddress)
    {
        // only this, the tournamentFactory or rounds can call createRound
        require(msg.sender == address(this) || msg.sender == IMatryxPlatform(platformAddress).getTournamentFactoryAddress() || stateData.isRound[msg.sender]);
        require((roundData.start >= now && roundData.start < roundData.end), "Time parameters are invalid.");

        IMatryxRoundFactory roundFactory = IMatryxRoundFactory(matryxRoundFactoryAddress);
        address newRoundAddress;

        if(_automaticCreation == false)
        {
            require(roundData.bounty > 0);
        }

        newRoundAddress = roundFactory.createRound(platformAddress, this, msg.sender, stateData.rounds.length, roundData);

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