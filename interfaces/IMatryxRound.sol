pragma solidity ^0.4.18;

interface IMatryxRound
{
	function bountyMTX() public returns (uint256);
	function removeSubmission(address _author, bytes32 externalAddress) public returns (bool);
	function isOpen() public constant returns (bool);
	function isInReview() public constant returns (bool);
	function submissionIsAccessible(uint256 _index) public constant returns (bool);
	function requesterIsContributor(address _requester) public constant returns (bool);
	function setParticipantType(address _participantAddress, uint256 _type) public;
	function getTokenAddress() public constant returns (address);
	function getSubmissions() public constant returns (address[] _submissions);
	function getSubmissionBody(uint256 _index) public constant returns (bytes32 externalAddress_Versioned);
	function getSubmissionAuthor(uint256 _index) public constant returns (address) ;
	function submissionChosen() public constant returns (bool);
	function getWinningSubmissionAddress() public constant returns (address);
	function numberOfSubmissions() public constant returns (uint256);
	function Start(uint256 _duration, uint256 _reviewPeriod) public;
	function chooseWinningSubmission(address _submissionAddress) public;
	function awardBounty(address _submissionAddress, uint256 _remainingBounty) public;
	function createSubmission(string _name, address _author, bytes32 _externalAddress, address[] _references, address[] _contributors, bool _publicallyAccessible) public returns (address _submissionAddress);
	function getBalance(address _submissionAddress) public returns (uint256);
}