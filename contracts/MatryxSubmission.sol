pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./LibGlobals.sol";
import "./IToken.sol";

import "./MatryxSystem.sol";
import "./MatryxPlatform.sol";
import "./MatryxCommit.sol";
import "./MatryxTrinity.sol";
import "./MatryxRound.sol";

contract MatryxSubmission is MatryxTrinity {
    constructor (uint256 _version, address _system) MatryxTrinity(_version, _system) public {}
}

interface IMatryxSubmission {
    function getVersion() external view returns (uint256);
    function getTournament() external view returns (address);
    function getRound() external view returns (address);

    function getOwner() external view returns (address);
    function getTitle() external view returns (bytes32[3] memory);
    function getDescriptionHash() external view returns (bytes32[2] memory);
    function getContents() external view returns (bytes32[2] memory);
    function getTimeSubmitted() external view returns (uint256);
    function getTimeUpdated() external view returns (uint256);
    function getReward() external view returns (uint256);
    function getBalance() external view returns (uint256);
    function getTotalWinnings() external view returns (uint256);
    function getData() external view returns (LibSubmission.SubmissionReturnData memory);

    function addFunds(uint256) external;
    function updateDetails(bytes32[3] calldata title, bytes32[2] calldata descHash) external;

    function getAvailableReward() external view returns (uint256); // needs to change
    function withdrawReward() external;                            // needs to change
}

library LibSubmission {
    using SafeMath for uint256;

    struct SubmissionInfo {
        uint256 version;
        address owner;
        address tournament;
        address round;
        uint256 timeSubmitted;
        uint256 timeUpdated;
        uint256 reward;
    }

    // All information needed for creation of Submission
    struct SubmissionDetails {
        bytes32[3] title;
        bytes32[2] descHash;
        bytes32 commitHash;
    }

    // bytes32[2] publicKey;
    // bytes32    privateKey;

    // All state data and details of Submission
    struct SubmissionData {
        LibSubmission.SubmissionInfo info;
        LibSubmission.SubmissionDetails details;

        mapping(address=>uint256) availableReward;
        uint256 totalAllocated;

        mapping(address=>uint256) contribValue;
        address[] contributors;
        bytes32 commitVarToRenameLater; // commit we left off when calculating contributor total values
    }

    // everything but the mappings
    struct SubmissionReturnData {
        LibSubmission.SubmissionInfo info;
        LibSubmission.SubmissionDetails details;
    }

    function onlyOwner(address self, address sender, MatryxPlatform.Data storage data) internal view {
        require(data.submissions[self].info.owner == sender, "Must be owner");
    }

    function duringOpenSubmission(address self, MatryxPlatform.Data storage data) internal view {
        address round = data.submissions[self].info.round;
        require(IMatryxRound(round).getState() == uint256(LibGlobals.RoundState.Open), "Must be open Round");
    }

    /// @dev Returns the version of this Submission
    function getVersion(address self, address, MatryxPlatform.Data storage data) external view returns (uint256) {
        return data.submissions[self].info.version;
    }

    /// @dev Returns the Tournament address of this Submission
    function getTournament(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        address round = data.submissions[self].info.round;
        return data.rounds[round].info.tournament;
    }

    /// @dev Returns the Round address of this Submission
    function getRound(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.submissions[self].info.round;
    }

    /// @dev Returns the owner of this Submission
    function getOwner(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.submissions[self].info.owner;
    }

    /// @dev Returns the title of this Submission
    function getTitle(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[3] memory) {
        return data.submissions[self].details.title;
    }

    /// @dev Returns the description hash of this Submission
    function getDescriptionHash(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[2] memory) {
        return data.submissions[self].details.descHash;
    }

    /// @dev Returns the file hash of this Submission if the sender has file viewing permissions, and an empty array otherwise
    function getContents(address self, address sender, MatryxPlatform.Data storage data, LibCommit.CommitData storage commitData) public view returns (bytes32[2] memory) {
        bytes32 commitHash = data.submissions[self].details.commitHash;
        return commitData.commits[commitHash].contentHash;
    }

    /// @dev Returns the time this Submission was submitted
    function getTimeSubmitted(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.submissions[self].info.timeSubmitted;
    }

    /// @dev Returns the time this Submission was last updated
    function getTimeUpdated(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.submissions[self].info.timeUpdated;
    }

    /// @dev Returns this Submission's reward
    function getReward(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.submissions[self].info.reward;
    }

    /// @dev Returns the MTX balance of this Submission
    function getBalance(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.balanceOf[self];
    }

    /// @dev Returns the total winnings of this Submission
    function getTotalWinnings(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.submissions[self].info.reward;
    }

    /// @dev Returns all information of this Submission
    function getData(address self, address sender, MatryxPlatform.Data storage data) public view returns (LibSubmission.SubmissionReturnData memory) {
        SubmissionReturnData memory sub;
        sub.info = data.submissions[self].info;
        sub.details = data.submissions[self].details;

        return sub;
    }

    /// @dev Adds funds to the Submission
    /// @param self      Address of this Submission
    /// @param sender    msg.sender to the Submission
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param amount    Amount of MTX to add
    function addFunds(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, uint256 amount) public {
        require(IToken(info.token).allowance(sender, address(this)) >= amount, "Must approve funds first");

        data.totalBalance = data.totalBalance.add(amount);
        data.balanceOf[self] = data.balanceOf[self].add(amount);
        data.users[sender].totalSpent = data.users[sender].totalSpent.add(amount);
        require(IToken(info.token).transferFrom(sender, address(this), amount), "Transfer failed");
    }

    /// @dev Updates the details of this Submission
    /// @param self     Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param data     Data struct on Platform
    function updateDetails(address self, address sender, MatryxPlatform.Data storage data, bytes32[3] memory title, bytes32[2] memory descHash) public {
        onlyOwner(self, sender, data);
        duringOpenSubmission(self, data);

        LibSubmission.SubmissionDetails storage details = data.submissions[self].details;

        if (title[0] != 0) details.title = title;
        if (descHash[0] != 0) details.descHash = descHash;

        data.submissions[self].info.timeUpdated = now;
    }

    /// @dev Get the reward available to the caller on this Submission
    /// @param self    Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param data    Data struct on Platform
    /// @return        Amount of MTX available to msg.sender
    function getAvailableReward(address self, address sender, MatryxPlatform.Data storage data, LibCommit.CommitData storage commitData) public view returns (uint256) {
        LibSubmission.SubmissionData storage submission = data.submissions[self];

        uint256 balance = data.balanceOf[self];
        uint256 remainingReward = balance.sub(submission.totalAllocated);
        uint256 share = submission.availableReward[sender];

        if (remainingReward > 0) {
            bytes32 commitHash = submission.details.commitHash;
            uint256 commitTotal = commitData.commits[commitHash].totalValue;
            uint256 senderTotal;

            for(uint256 i = commitData.commits[commitHash].height; i > 0; i--) {
                if (commitData.commits[commitHash].creator == sender) {
                    senderTotal += commitData.commits[commitHash].value;
                }
                commitHash = commitData.commits[commitHash].parentHash;
            }

            share = share.add(remainingReward.mul(senderTotal).div(commitTotal));
        }

        return share;
    }

    event LiterallySomthing(bool isReady);
    function calculateContributions(address self, address sender, MatryxPlatform.Data storage data, LibCommit.CommitData storage commitData) public {
        LibSubmission.SubmissionData storage submission = data.submissions[self];
        bytes32 commitHash = submission.commitVarToRenameLater;

        require(commitHash != bytes32(0), "calculateContributions already completed");

        for (uint256 i = commitData.commits[commitHash].height; i > 0; i--) {
            if (gasleft() < 50000) {
                submission.commitVarToRenameLater = commitHash;
                emit LiterallySomething(false);                        
                return;
            }
            
            address contributor = commitData.commits[commitHash].creator;
            uint256 value = commitData.commits[commitHash].value;

            if (submission.contribValue[contributor] == 0) {
                submission.contributors.push(contributor);
            }
            submission.contribValue[contributor] = submission.contribValue[contributor].add(value);

            // traverse to parent
            commitHash = commitData.commits[commitHash].parentHash;
        }

        // "done", can withdraw now
        submission.commitVarToRenameLater = bytes32(0);
        emit LiterallySomething(true);                        
    }

    /// @dev Sets the reward allocation for each contributor to this submission when someone withdraws
    /// @param self    Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param data    Data struct on Platform
    function calculateRewardAllocation(address self, address sender, MatryxPlatform.Data storage data, LibCommit.CommitData storage commitData) internal {
        LibSubmission.SubmissionData storage submission = data.submissions[self];

        uint256 balance = data.balanceOf[self];
        uint256 remainingReward = balance.sub(submission.totalAllocated);

        // if no new reward to allocate, return early
        if (remainingReward == 0) return;
        submission.totalAllocated = submission.totalAllocated.add(remainingReward);

        uint256 distTotal = commitData.commits[submission.details.commitHash].totalValue;

        for (uint256 i = 0; i < submission.contributors.length; i++) {
            address contrib = submission.contributors[i];
            uint256 share = remainingReward.mul(submission.contribValue[contrib]).div(distTotal);

            submission.availableReward[contrib] = submission.availableReward[contrib].add(share);
        }
    }

    /// @dev Allows the owner and contributors to this Submission to withdraw from this Submission
    /// @param self    Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    function withdrawReward(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibSubmission.SubmissionData storage submission = data.submissions[self];
        require(submission.commitVarToRenameLater == bytes32(0), "Must call calculateContributions until complete");

        uint256 share = submission.availableReward[sender];
        require(share > 0, "Already withdrawn full amount");

        submission.availableReward[sender] = 0;
        data.users[sender].totalWinnings = data.users[sender].totalWinnings.add(share);
        submission.totalAllocated = submission.totalAllocated.sub(share);

        data.totalBalance = data.totalBalance.sub(share);
        data.balanceOf[self] = data.balanceOf[self].sub(share);
        IToken(info.token).transfer(sender, share);
    }
}

// NOTE to withdraw reward, must call calculateContributions until completion