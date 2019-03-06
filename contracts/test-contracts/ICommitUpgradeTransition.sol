interface ICommitUpgradeTransition {
    function upgradeCommitAndAncestry(bytes32 commitHash) external;
}