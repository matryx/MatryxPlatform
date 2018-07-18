pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";
import "../MatryxSubmission.sol";

contract MatryxSubmissionFactory {
    function createSubmission(LibConstruction.RequiredSubmissionAddresses requiredAddresses, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress) {
        return new MatryxSubmission(requiredAddresses, submissionData);
    }
}
