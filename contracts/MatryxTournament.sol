pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxEntity.sol";
import "./IMatryxToken.sol";

import "./MatryxProxy.sol";
import "./MatryxPlatform.sol";
import "./MatryxRound.sol";
import "./MatryxSubmission.sol";

import "./LibGlobals.sol";

contract MatryxTournament is MatryxEntity {
    constructor (uint256 _version, address _proxy) MatryxEntity(_version, _proxy) public {}
}

interface IMatryxTournament {
    function transferTo(address, address, uint256) external;

    function getOwner() external view returns (address);
    function getTitle() external view returns (bytes32[3]);
    function getCategory() external view returns (bytes32);
    function getDescriptionHash() external view returns (bytes32[2]);
    function getFileHash() external view returns (bytes32[2]);
    function getBounty() external view returns (uint256);

    function getRounds() external view returns (address[]);
    function getDetails() external view returns (LibTournament.TournamentDetails);

    function enterTournament() external;
    function createRound(LibRound.RoundDetails) external returns (address);
    function createSubmission(LibSubmission.SubmissionDetails) external returns (address);

    function selectWinners(LibRound.SelectWinnersData, LibRound.RoundDetails) external;
}

// dependents: LibPlatform
library LibTournament {
    event RoundCreated(address roundAddress);
    event SubmissionCreated(address submissionAddress);

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
        address[] entrants;
        mapping(address=>LibGlobals.o_uint256) entryFeePaid;
    }

    /// @dev Returns the owner of this Tournament
    function getOwner(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.tournaments[self].owner;
    }

    /// @dev Returns the title of this Tournament
    function getTitle(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[3]) {
        return data.tournaments[self].details.title;
    }

    /// @dev Returns the category of this Tournament
    function getCategory(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32) {
        return data.tournaments[self].details.category;
    }

    /// @dev Returns the description hash of this Tournament
    function getDescriptionHash(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        return data.tournaments[self].details.descHash;
    }

    /// @dev Returns the file hash of this Tournament
    function getFileHash(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        return data.tournaments[self].details.fileHash;
    }

    /// @dev Returns the bounty of this Tournament
    function getBounty(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.tournaments[self].details.bounty;
    }

    /// @dev Returns all Round addresses of this Tournament
    function getRounds(address self, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.tournaments[self].rounds;
    }

    /// @dev Returns the data struct of this Tournament
    function getDetails(address self, address, MatryxPlatform.Data storage data) public view returns (LibTournament.TournamentDetails) {
        return data.tournaments[self].details;
    }

    /// @dev Enter Tournament
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param data    Data struct on Platform
    function enterTournament(address self, address sender, MatryxPlatform.Data storage data) public {
        require(data.users[sender].exists, "Must have entered Matryx");
        require(sender != data.tournaments[self].owner, "Cannot enter own Tournament");
        // TODO: actually transfer entry fee MTX
        data.tournaments[self].entryFeePaid[sender].exists = true;
        data.users[sender].tournamentsEntered.push(self);
    }

    /// @dev Creates a new Round on this Tournament
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param rDetails  Details of the Round being created
    /// @return          Address of the created Round
    function createRound(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibRound.RoundDetails rDetails) public returns (address) {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.owner, "Must be owner");
        // require(MatryxToken(info.token).)

        address rAddress = new MatryxRound(info.version, info.proxy);
        MatryxProxy(info.proxy).setContractType(rAddress, MatryxProxy.ContractType.Round);
        data.allRounds.push(rAddress);
        emit RoundCreated(rAddress);

        IMatryxTournament(self).transferTo(info.token, rAddress, rDetails.bounty);

        tournament.rounds.push(rAddress);

        LibRound.RoundData storage round = data.rounds[rAddress];
        round.tournament = self;
        round.details = rDetails;

        return rAddress;
    }

    /// @dev Creates a new Submissions
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param sDetails  Submission details (title, descHash, fileHash)
    /// @return          Address of the created Submission
    function createSubmission(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibSubmission.SubmissionDetails sDetails) public returns (address) {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(tournament.entryFeePaid[sender].exists, "Must have paid entry fee");

        address sAddress = new MatryxSubmission(info.version, info.proxy);
        MatryxProxy(info.proxy).setContractType(sAddress, MatryxProxy.ContractType.Submission);
        data.allSubmissions.push(sAddress);
        data.users[sender].submissions.push(sAddress);
        emit SubmissionCreated(sAddress);

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

    function selectWinners(MatryxPlatform.Data storage data, LibRound.SelectWinnersData winnerData, LibRound.RoundDetails rDetails) public {
        // Flag the Winning Submissions
        // Allocate the reward distribution to them 
        // Maybe for POC just automatically start next round on choosing winners
    }
}
