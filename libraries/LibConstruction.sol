pragma solidity ^0.4.18;

library LibConstruction
{
	struct RequiredTournamentAddresses
    {
        address platformAddress;
        address matryxTokenAddress;
        address roundFactoryAddress;
    }

    struct RequiredRoundAddresses
    {
    	address platformAddress;
    	address matryxTokenAddress;
    	address tournamentAddress;
    	address submissionFactoryAddress;
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

    struct SubmissionData
    {
    	string title;
    	address owner;
    	bytes contentHash;
    	address[] contributors;
    	uint128[] contributorRewardDistribution;
    	address[] references;
    }
}