pragma solidity ^0.4.11;

//MatryxPlatformMain


//Import all necessary contracts
import "./Tournament.sol";
import './Ownable.sol';

//import submissions contract

//Initialize the contract
contract MatryxPlatformAlphaMain is Ownable{

	//Initialize variables
  address[] public allTournaments; //convert into a map?
  //TODO for when anyone can submit a tournament
  // mapping(address => TournamentSubmitters) public submitters



  //Create a new tournament if you own the contract ie: just Matrx Team for now.
  function createTournament(owner, tournamentName, startRoundTime, roundEndTime, reviewPeriod, endOfTournamentTime, bountyMTX,currentRound, maxRounds) {
    uint maxRounds = 1;

    address newTournament = new Tournament(owner, tournamentName, startRoundTime, roundEndTime, reviewPeriod, endOfTournamentTime, bountyMTX,currentRound, maxRounds);
    allTournaments.push(newTournament);
    
  }

  //Show a list of all the tournaments
  function getTournmentList(){
    return allTournaments;
  }


}