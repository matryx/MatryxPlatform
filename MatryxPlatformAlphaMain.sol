pragma solidity ^0.4.11;

//MatryxPlatformMain


//Import all necessary contracts
import "./TournamentContract.sol";
import './Ownable.sol';

//import submissions contract

//Initialize the contract
contract MatryxPlatformMain is Ownable{

	//Initialize variables
	Tournament[] public tournaments
 

	//Map the people who submit a tournament
	mapping(address => Submitters) public submitters;


/**
   * Creating a tournament
   * @param creator who made the tournament
   * @param submitter who got the tokens
   * @param bounty weis paid for purchase
   * @param amount amount of tokens purchased
   */ 


	//Create a new tournament
	function createTournament(creator,)

	//Show a list of all the tournaments


	//Create a new submission





	// This is a type for a single tournament proposal.
    struct Tournament {
        bytes32 name;   // short name (up to 32 bytes)

        uint voteCount; // number of accumulated votes
    }

    address public tournamentOwner;


    // A dynamically-sized array of `Tournament` structs.
    Tournament[] public tournaments;


}