pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";
import "../MatryxSubmission.sol";

contract MatryxSubmissionFactory {
    // function createSubmission(address[3] requiredAddresses, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress) {
    function createSubmission(address _owner, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress) {
        // return new MatryxSubmission(requiredAddresses, submissionData);
        return new MatryxSubmission(_owner, submissionData);
        // return new MatryxSubmission(_owner);
    }
}
