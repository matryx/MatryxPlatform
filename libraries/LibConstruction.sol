pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

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
        bytes32 category;
        bytes32[3] title;
        bytes32[2] descriptionHash;
        bytes32[2] fileHash;
        uint256 initialBounty;
        uint256 entryFee;
    }

    struct TournamentModificationData
    {
        bytes32 category;
        bytes32[3] title;
        bytes32[2] descriptionHash;
        bytes32[2] fileHash;
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
        bytes32[3] title;
        bytes32[2] descriptionHash;
        bytes32[2] fileHash;
        uint256 timeSubmitted;
        uint256 timeUpdated;
    }

    struct ContributorsAndReferences
    {
        address[] contributors;
        uint128[] contributorRewardDistribution;
        address[] references;
    }

    struct SubmissionModificationData
    {
        bytes32[3] title;
        bytes32[2] descriptionHash;
        bytes32[2] fileHash;
    }

    struct ContributorsModificationData
    {
        address[] contributorsToAdd;
        uint128[] contributorRewardDistribution;
        address[] contributorsToRemove;
    }

    struct ReferencesModificationData
    {
        address[] referencesToAdd;
        address[] referencesToRemove;
    }
}
