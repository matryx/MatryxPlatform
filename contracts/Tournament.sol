pragma solidity ^0.4.11;

import './Ownable.sol';
import './Submission.sol';


///Creating a Tournament and the functionality
contract Tournament is Ownable{

    //Initialize Tournament Variables
    address public tournamentOwner;
    string public tournamentName;
    uint256 public startRoundTime;
    uint256 public roundEndTime;
    uint256 public reviewPeriod;
    uint256 public endOfTournamentTime;
    uint public bountyMTX;
    uint public currentRound; //0
    uint public maxRounds = 1;
    bool public tournamentActive = true;


    //TODO create a wallet for each of the tournaments
    bool submissionsViewable; //Should we make this a dictionary with nrounds:true/false

    //Make event for submission being made to the tournament, grab as many submissions

    //Initialize submission Variables
    address[] submissionList;
    string[] submissionNames;

    //Init all basic submission
    string name;
    address submissionOwner;
    string title;
    string body; //placeholder for description or something
    string references;
    string contributors;
    string ipfsHash;
    uint256 timeSubmitted;

    //Create a mapping with the people who created a submission so they can view the submissionBody
    // mapping(address => bool)

    // endOfTournamentTime=roundEndTime+reviewPeriod;
    //Force roundCap to 1 round for alpha
    // maxRounds = 1; 

    //Logic for active vs. inactive tournaments
    // tournamentActive = true;
    // if(endOfTournamentTime <= now){
    //     tournamentActive = false;
    // }

    // if(tournamentActive == true){
    function createSubmission(tournamentOwner, msg.sender, name, submissionOwner, title, body, references, contributors, ipfsHash,  timeSubmitted, roundEndTime){
        address newSubmission = new Submission(tournamentOwner, msg.sender, name, submissionOwner, title, body, references, contributors, 
           ipfsHash,  timeSubmitted, roundEndTime);
        submissionList.push(newSubmission);
        submissionNames.push(name);
    }
    // }

    //Tournament Constructor
    function Tournament(address _tournamentOwner, string _tournamentName, uint256 _startRoundTime, uint256 _roundEndTime, uint256 _reviewPeriod, 
        uint256 _endOfTournamentTime, uint _bountyMTX, uint _currentRound, uint _maxRounds){
        //Clean the inputs
        //Clean inputs
        require(_tournamentOwner != 0x0);
        require(_tournamentName != "");
        require(_startRoundTime >= now);
        require(_roundEndTime >  now);
        require(_reviewPeriod != "");
        require(_endOfTournamentTime >  now);
        require(_bountyMTX > 0);
        require(_currentRound >= 0);
        require(_maxRounds >= 0);

        //Constructor assignments
    tournamentOwner = _tournamentOwner;
    tournamentName = _tournamentNameour;
    startRoundTime = _startRoundTime;
    roundEndTime = _roundEndTime;
    reviewPeriod = _reviewPeriod;
    endOfTournamentTime = _endOfTournamentTime;
    bountyMTX = _bountyMTX;
    currentRound = _currentRound; //0
    maxRounds = _maxRounds;
    }

    }//end of contract


