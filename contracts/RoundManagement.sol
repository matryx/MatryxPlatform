pragma solidity ^0.4.18;

import '../libraries/strings/strings.sol';
import '../libraries/math/SafeMath.sol';
import '../interfaces/IMatryxPlatform.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/factories/IMatryxRoundFactory.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/IMatryxToken.sol';
import './Ownable.sol';

/// @title Tournament - The Matryx tournament.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract RoundManagement is Ownable
{
	using SafeMath for uint256;

	// TODO: condense and put in structs
    //Platform identification
    address public platformAddress;
    address public matryxTokenAddress;
    address public matryxRoundFactoryAddress;

    //Tournament identification
    string public title;
    bytes public externalAddress;
    string public discipline;

    // Timing and State
    uint256 public timeCreated;
    uint256 public tournamentOpenedTime;
    address[] public rounds;
    mapping(address=>bool) public isRound;
    uint256 public reviewPeriod;
    uint256 public tournamentClosedTime;
    uint public maxRounds = 3;
    bool public tournamentOpen = false;

    // Reward and fee
    uint256 public BountyMTX;
    uint256 public BountyMTXLeft;
    uint256 public entryFee;

    // TODO: Automatic round creation mechanism

    // Submission tracking
    uint256 numberOfSubmissions = 0;
    mapping(address=>address[]) private entrantToSubmissions;
    mapping(address=>mapping(address=>uint256_optional)) private entrantToSubmissionToSubmissionIndex;
    mapping(address=>uint256_optional) private addressToIsEntrant;
    address[] private allEntrants;

    /*
     * Structs
     */

    struct uint256_optional
    {
        bool exists;
        uint256 value;
    }

    struct SubmissionLocation
    {
        uint256 roundIndex;
        uint256 submissionIndex;
    }

    /*
     * Events
     */

    event RoundStarted(uint256 _roundIndex);
    // Fired at the end of every round, one time per submission created in that round
    event SubmissionCreated(uint256 _roundIndex, address _submissionAddress);
    event RoundWinnerChosen(address _submissionAddress);

    function isInReview() public view returns (bool)
    {
        return now >= tournamentClosedTime && now <= tournamentClosedTime + reviewPeriod;
    }

    /// @dev Chooses the winner for the round. If this is the last round, closes the tournament.
    /// @param _submissionAddress Address of the winning submission
    function chooseWinner(address _submissionAddress) public
    {
        // TODO: Implement popular vote default winner chosen to avoid
        // locking up MTX in this tournament (would happen if the tournament
        // poser tried to choose a winner after the review period ended).
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        round.chooseWinningSubmission(_submissionAddress);
        RoundWinnerChosen(_submissionAddress);

        if(rounds.length == maxRounds)
        {
            require(isInReview());
            tournamentOpen = false;

            IMatryxPlatform platform = IMatryxPlatform(platformAddress);
            platform.invokeTournamentClosedEvent(this, rounds.length, _submissionAddress, round.getBounty());
        }
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(uint256 _bountyMTX) public returns (address _roundAddress) 
    {
        IMatryxRoundFactory roundFactory = IMatryxRoundFactory(matryxRoundFactoryAddress);
        IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
        address newRoundAddress;

        if(rounds.length+1 == maxRounds)
        {
            uint256 lastBounty = BountyMTXLeft;
            newRoundAddress = roundFactory.createRound(platformAddress, this, msg.sender, BountyMTXLeft);
            BountyMTXLeft = 0;
            // Transfer the round bounty to the round.
            matryxToken.transfer(newRoundAddress, lastBounty);
        }
        else
        {
            uint256 remainingBountyAfterRoundCreated = BountyMTXLeft.sub(_bountyMTX);
            newRoundAddress = roundFactory.createRound(platformAddress, this, msg.sender, _bountyMTX);
            BountyMTXLeft = remainingBountyAfterRoundCreated;
            // Transfer the round bounty to the round.
            matryxToken.transfer(newRoundAddress, _bountyMTX);
        }
        
        isRound[newRoundAddress] = true;
        rounds.push(newRoundAddress);
        return newRoundAddress;
    }

    /// @dev Starts the latest round.
    /// @param _duration Duration of the round in seconds.
    function startRound(uint256 _duration, uint256 _reviewPeriod) public
    {
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        round.Start(_duration, _reviewPeriod);
        if(!tournamentOpen)
        {
            openTournament();
        }

        if(rounds.length == maxRounds)
        {
            tournamentClosedTime = now + _duration;
        }

        RoundStarted(rounds.length-1);
    }

    /// @dev Opens this tournament up to submissions; called by startRound.
    function openTournament() internal
    {
        tournamentOpen = true;
        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        platform.invokeTournamentOpenedEvent(owner, this, title, externalAddress, BountyMTX, entryFee);
    }
}