pragma solidity ^0.4.18;

library LibConstruction
{
    struct RequiredTournamentAddresses
    {
        address platformAddress;
        address roundFactoryAddress;
    }

    struct RequiredRoundAddresses
    {
        address platformAddress;
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
        string category;
        bytes32 title_1;
        bytes32 title_2;
        bytes32 title_3;
        bytes32 descriptionHash_1;
        bytes32 descriptionHash_2;
        bytes32 fileHash_1;
        bytes32 fileHash_2;
        uint256 initialBounty;
        uint256 entryFee;
    }

    struct TournamentModificationData
    {
        bytes32 title_1;
        bytes32 title_2;
        bytes32 title_3;
        bytes32 descriptionHash_1;
        bytes32 descriptionHash_2;
        bytes32 fileHash_1;
        bytes32 fileHash_2;
        uint256 entryFee;
        bool entryFeeChanged;
    }

    struct RoundData
    {
        uint256 start;
        uint256 end;
        uint256 reviewPeriodDuration;
        uint256 bounty;
        bool closed;
    }

    struct SubmissionData
    {
        string title;
        address owner;
        bytes descriptionHash;
        bytes fileHash;
        bool isPublic;
    	//address[] contributors;
    	//uint128[] contributorRewardDistribution;
    	//address[] references;
    }

    struct SubmissionModificationData
    {
        string title;
        address owner;
        bytes descriptionHash;
        bytes fileHash;
        bool isPublic;
    	//address[] contributorsToAdd;
    	//uint128[] contributorRewardDistribution;
    	//address[] contributorsToRemove;
    }
}
