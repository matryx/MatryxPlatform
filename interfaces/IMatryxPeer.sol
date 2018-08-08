pragma solidity ^0.4.18;

interface IMatryxPeer
{
    function getReputation() public view returns (uint128);
    function receiveTrust(uint128 _newTotalTrust, uint128 _senderReputation) public returns (uint128);
    function receiveDistrust(uint128 _newTotalTrust, uint128 _senderReputation) public returns (uint128);
    function flagMissingReference(address _submissionAddress, address _missingReference) public;
    function removeMissingReferenceFlag(address _submissionAddress, address _missingReference) public;
    function getReferenceProportion(address _submissionAddress) public view returns (uint128);
    function peersJudged() public view returns (uint256);
    //function normalizedTrustInPeer(address _peer) public view returns (uint128);
}
