pragma solidity ^0.4.18;

library LibConstruction
{
	struct RequiredTournamentAddresses
    {
        address platformAddress;
        address matryxTokenAddress;
        address roundFactoryAddress;
    }

    struct TournamentData
    {
    	string category;
    	string title;
    	bytes contentHash;
    	uint256 Bounty;
    	uint256 entryFee;
    }

    struct RoundData
    {
    	uint256 start;
    	uint256 end;
    	uint256 reviewDuration;
    	uint256 bounty;
    }
}