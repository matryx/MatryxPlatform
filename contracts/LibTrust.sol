pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./MatryxPlatform.sol";

library LibTrust
{
    using SafeMath for uint256;

    // Stored by the platform
    struct TrustData {
        mapping(address=>mapping(address=>bool)) hasJudged;         // Whether or not a peer has judged another peer
        mapping(address=>address[]) judgingPeers;                   // All peers that have judged a peer
        mapping(address=>mapping(address=>uint256)) sat_ij;         // sum of satisfactory transaction values from one account to another
        mapping(address=>mapping(address=>uint256)) satunsat_ij;    // sum of all transaction values from one account to another
        mapping(address=>mapping(address=>uint256)) c_ij;           // normalized opinion value from one peer to another (sat_ij/satunsat_ij)
        mapping(address=>mapping(address=>uint256)) infl_ij;        // Stores the net influences each peer has on each other peer's global reputation
    }

    /// @dev Gets the starting reputation for a new peer given the current number of peers
    /// @return The reputation of the peer (less than one, eighteen decimal representation)
    function getReputationForNewPeer(uint256 _peerCount) internal view returns (uint256)
    {
        uint256 integralTopValue = fastSigmoid(_peerCount+2);
        uint256 integralBottomValue = fastSigmoid(_peerCount+1);
        uint256 trustValue = integralTopValue.sub(integralBottomValue);

        return trustValue;
    }

    /// @dev Computes a value along a 'sigmoid' curve (sufficient for peer reputation infinite summation to one)
    /// @param _input An x value along the curve
    /// @return A y value along the curve
    function fastSigmoid(uint256 _input) public pure returns (uint256)
    {
        uint256 one = 1 * 10**18;
        uint256 two = 2 * 10**18;
        uint256 inputWithDecimals = _input * 10**18;

        return (two.mul(inputWithDecimals)).div(one.add(inputWithDecimals));
    }

    /// @dev Gives a peer initial trust. This is done once per address.
    /// @param data Data struct on platform.
    /// @param trustData User trust information.
    /// @param _peer The peer receiving initial trust
    function giveInitialTrust(MatryxPlatform.Data storage data, TrustData storage trustData, address _peer) public
    {
        data.users[_peer].reputation = getReputationForNewPeer(data.allUsers.length);
    }

    /// @dev Gives some amount of trust to a peer from msg.sender's peer account.
    /// @param data Data struct on platform.
    /// @param trustData User trust information.
    /// @param judger The peer giving trust
    /// @param judgee The peer to give trust to
    function trust(MatryxPlatform.Data storage data, TrustData storage trustData, address judger, address judgee) public
    {
        require(judger != judgee, "Peer must not judge self");
        // Recompute s_ij
        trustData.sat_ij[judger][judgee] = trustData.sat_ij[judger][judgee].add(1);
        trustData.satunsat_ij[judger][judgee] = trustData.sat_ij[judger][judgee].add(1);
        trustData.c_ij[judger][judgee] = trustData.sat_ij[judger][judgee].mul(1e18 / (trustData.satunsat_ij[judger][judgee]));

        updateReputation(data, trustData, judger, judgee);
        address[] memory judgingPeers = trustData.judgingPeers[judgee];
        for(uint256 i = 0; i < judgingPeers.length; i++) {
            updateReputation(data, trustData, judgingPeers[i], judgee);
        }
    }

    /// @dev Gives some amount of distrust to a peer from msg.sender's peer account.
    /// @param data Data struct on platform.
    /// @param trustData User trust information.
    /// @param judger The peer giving distrust
    /// @param judgee The peer to give distrust to
    function distrust(MatryxPlatform.Data storage data, TrustData storage trustData, address judger, address judgee) public
    {
        require(judger != judgee, "Peer must not judge self");
        // Recompute s_ij
        trustData.satunsat_ij[judger][judgee] = trustData.satunsat_ij[judger][judgee].add(1);
        trustData.c_ij[judger][judgee] = trustData.sat_ij[judger][judgee].mul(1e18 / (trustData.satunsat_ij[judger][judgee]));

        updateReputation(data, trustData, judger, judgee);
        address[] memory judgingPeers = trustData.judgingPeers[judgee];
        for(uint256 i = 0; i < judgingPeers.length; i++) {
            updateReputation(data, trustData, judgingPeers[i], judgee);
        }
    }

    /// @dev Updates a user's reputation.
    /// @param data Data struct on platform.
    /// @param trustData User trust information.
    /// @param judger The peer giving trust or distrust
    /// @param judgee The peer receiving trust or distrust
    function updateReputation(MatryxPlatform.Data storage data, TrustData storage trustData, address judger, address judgee) internal {
        uint256 judgerRep = data.users[judger].reputation;
        uint256 judgeeRep = data.users[judgee].reputation;
        uint256 prvInfluence_ij = trustData.infl_ij[judger][judgee];
        uint256 newInfluence_ij = judgerRep.mul(trustData.c_ij[judger][judgee]).div(1e18);

        if(!trustData.hasJudged[judger][judgee])
        {
            trustData.hasJudged[judger][judgee] = true;
            trustData.judgingPeers[judger].push(judgee);
        }

        judgeeRep = judgeeRep.sub(prvInfluence_ij).add(newInfluence_ij);
        data.users[judgee].reputation = judgeeRep;

        // update entry for judgers last influence on judged peer's rep
        if(prvInfluence_ij != newInfluence_ij) {
            trustData.infl_ij[judger][judgee] = newInfluence_ij;
        }
    }
}