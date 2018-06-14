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

    struct RequiredSubmissionAddresses
    {
    	address platformAddress;
    	address tournamentAddress;
    	address roundAddress;
    }

    struct TournamentData
    {
        // string category;
        // ^ was causing revert in platform.createTournament
        bytes32 categoryHash;
    	bytes32 title_1;
        bytes32 title_2;
        bytes32 title_3;
    	bytes32 contentHash_1;
        bytes32 contentHash_2;
    	uint256 Bounty;
    	uint256 entryFee;
    }

    struct TournamentModificationData
    {
    	bytes32[4] title;
    	bytes32[2] contentHash;
    	uint256 entryFee;
    	bool entryFeeChanged;
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
    	//address[] contributors;
    	//uint128[] contributorRewardDistribution;
    	//address[] references;
    }

    struct SubmissionModificationData
    {
    	string title;
    	address owner;
    	bytes contentHash;
    	bool isPublic;
    	//address[] contributorsToAdd;
    	//uint128[] contributorRewardDistribution;
    	//address[] contributorsToRemove;
    }
}