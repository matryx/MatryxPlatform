pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxForwarder.sol";

import "./MatryxProxy.sol";
import "./MatryxPlatform.sol";
import "./MatryxRound.sol";
import "./MatryxSubmission.sol";

contract MatryxTournament is MatryxForwarder {
    constructor (uint256 _version, address _proxy) MatryxForwarder(_version, _proxy) public {}
}

interface IMatryxTournament {
    function getOwner() external view returns (address);

    function getTitle() external view returns (bytes32[3]);
    function getCategory() external view returns (bytes32);
    function getDescriptionHash() external view returns (bytes32[2]);
    function getFileHash() external view returns (bytes32[2]);
    function getBounty() external view returns (uint256);

    function getRounds() external view returns (address[]);
    function getData() external view returns (LibTournament.TournamentData);

    function createRound(LibRound.RoundDetails) external returns (address);
    function createSubmission(LibSubmission.SubmissionDetails) external returns (address);
}

library LibTournament {
    event RoundCreated(address _roundAddress);
    event SubmissionCreated(address _submissionAddress);

    // All information needed for creation of Tournament
    struct TournamentDetails {
        bytes32[3] title;
        bytes32 category;
        bytes32[2] descHash;
        bytes32[2] fileHash;
        uint256 bounty;
        uint256 entryFee;
    }

    // All state data and details of Tournament
    struct TournamentData {
        address owner;
        TournamentDetails details;
        address[] rounds;
    }

    /// @dev Returns the owner of this Tournament
    function getOwner(address self, address sender, MatryxPlatform.Data storage data) public view returns (address) {
        return data.tournaments[self].owner;
    }

    /// @dev Returns the title of this Tournament
    function getTitle(address self, address sender, MatryxPlatform.Data storage data) public view returns (bytes32[3]) {
        return data.tournaments[self].details.title;
    }

    /// @dev Returns the category of this Tournament
    function getCategory(address self, address sender, MatryxPlatform.Data storage data) public view returns (bytes32) {
        return data.tournaments[self].details.category;
    }

    /// @dev Returns the description hash of this Tournament
    function getDescriptionHash(address self, address sender, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        return data.tournaments[self].details.descHash;
    }

    /// @dev Returns the file hash of this Tournament
    function getFileHash(address self, address sender, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        return data.tournaments[self].details.fileHash;
    }

    /// @dev Returns the bounty of this Tournament
    function getBounty(address self, address sender, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.tournaments[self].details.bounty;
    }

    /// @dev Returns all round addresses of this Tournament
    function getRounds(address self, address sender, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.tournaments[self].rounds;
    }

    /// @dev Returns the data struct of this Tournament
    function getData(address self, address sender, MatryxPlatform.Data storage data) public view returns (LibTournament.TournamentData) {
        return data.tournaments[self];
    }

    /// @dev Creates a new Round on this Tournament
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to this Tournament
    /// @param info      Info struct on the Platform
    /// @param data      Data struct on the Platform
    /// @param rDetails  Details of the Round being created
    /// @return          Address of the created Round
    function createRound(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibRound.RoundDetails rDetails) public returns (address) {
        address rAddress = new MatryxRound(info.version, info.proxy);
        MatryxProxy(info.proxy).setContractType(rAddress, MatryxProxy.ContractType.Round);
        data.allRounds.push(rAddress);
        emit RoundCreated(rAddress);

        LibTournament.TournamentData storage tournament = data.tournaments[self];
        tournament.rounds.push(rAddress);

        LibRound.RoundData storage round = data.rounds[rAddress];
        round.tournament = self;
        round.details = rDetails;

        return rAddress;
    }

    /// @dev Creates a new Submissions
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to this Tournament
    /// @param info      Info struct on the Platform
    /// @param data      Data struct on the Platform
    /// @param sDetails  Submission details (title, descHash, fileHash)
    /// @return          Address of the created Submission
    function createSubmission(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibSubmission.SubmissionDetails sDetails) public returns (address) {
        address sAddress = new MatryxSubmission(info.version, info.proxy);
        MatryxProxy(info.proxy).setContractType(sAddress, MatryxProxy.ContractType.Submission);
        data.allSubmissions.push(sAddress);
        emit SubmissionCreated(sAddress);

        LibTournament.TournamentData storage tournament = data.tournaments[self];
        address roundAddress = tournament.rounds[tournament.rounds.length - 1];

        LibRound.RoundData storage round = data.rounds[roundAddress];
        round.submissions.push(sAddress);

        LibSubmission.SubmissionData storage submission = data.submissions[sAddress];
        submission.tournament = self;
        submission.round = roundAddress;
        submission.details = sDetails;
        submission.timeSubmitted = now;
        submission.timeUpdated = now;

        return sAddress;
    }
}
