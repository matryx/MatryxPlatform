pragma solidity ^0.4.18;

import "./Ownable.sol";
import "./MatryxQueryEncrypter.sol";

/// @title MatryxOracleMessenger - An oracle system for validating MTX balances on mainnet.
/// @author Max Howard - <max@nanome.ai>
contract MatryxOracleMessenger is Ownable {

  // An event to let our node know that a new query has been performed.
  event QueryPerformed(uint256 id, address sender);

  event StoredResponse(uint256 storedResponse);
  event ObtainedResponse(uint256 response);
  event FailedToStore(uint256 newResponse, uint256 oldResponse);
  event QueryID(uint256 id);

  // Map from user addresses to MatryxQueryEncrypters. We assume each user only
  // sends one query at a time.
  mapping(address => MatryxQueryEncrypter) internal queryEncrypters;
  // Map from user addresses (queriers) to QueryIDs. We assume each user only
  // makes one query at a time.
  mapping(address => uint256) internal fromQuerierToQueryID;
  // Map from QueryIDs to responses (bytes32s. aka dynamically-sized byte arrays.)
  mapping(uint256 => uint256) internal queryResponses;

  /// @dev Gets the latest response from the oracle (internal).
  /// @param _sender Address of sender who we wish to receive the oracle response for.
  /// @return _response Response from the oracle (an MTX balance).
  function latestResponseFromOracle(address _sender) internal view returns (uint256 _response)
  {
        uint256 queryID = fromQuerierToQueryID[_sender];
        uint256 response = queryResponses[queryID];
        return response;
  }

  /// @dev Uses [the user's existing]/[a new] QueryResolver,
  //       depending on whether or not the user has submitted a query before.
  // @param _query Bytes representing the query.
  // @param _sender Sender of the query (ie user checking their balance).
  // @return queryID for the Oracle to use in storing their response.
  function Query(bytes32 _query, address _sender) external {
    MatryxQueryEncrypter encrypter;
    // If there's already a queryResolver for this user
    if(address(queryEncrypters[_sender]) > 0x0)
    {
        // Use that one.
        encrypter = queryEncrypters[_sender];
    }
    else
    {
        // Otherwise, create a new one and assign it.
        encrypter = new MatryxQueryEncrypter(_sender);
        queryEncrypters[_sender] = encrypter;
    }

    // Get the queryID from the MatryxQueryEncrypter.
    uint256 queryID = encrypter.generateQueryID(_query);
    // Store that id under the sender's (querier's) address.
    fromQuerierToQueryID[_sender] = queryID;

    // Let our Alpha Matryx server know that a query has been performed!
    QueryPerformed(queryID, _sender);
  }

  /// @dev Stores a query response (Only to be used by MatryxPlatform, MatryxOracleMessenger and MatryxQueryEncrypter.)
  /// @param _queryID Query ID given to the oracle by this messenger.
  /// @param _response Response received from oracle.
  /// @return success Whether or not the query response was stored successfully (didn't already exist).
  function storeQueryResponse(uint256 _queryID,  uint256 _response) onlyOwner public returns (bool success)
  {
      // Make sure:
      // 1) The response is not empty and
      // 2) There has not yet been a response created for this query
      uint256 oldQueryID = fromQuerierToQueryID[msg.sender];
      uint256 existingResponse = queryResponses[oldQueryID];
      if(_response > 0 && existingResponse == 0)
      {
          // If these conditions hold, we set the response here.
          fromQuerierToQueryID[msg.sender] = _queryID;
          queryResponses[_queryID] = _response;
          StoredResponse(queryResponses[_queryID]);
          return true;
      }
      else
      {
          // Otherwise, we do nothing with the response,
          // and return false (unsuccessful storage of response).
          FailedToStore(_response, queryResponses[_queryID]);
          return false;
      }
  }
}