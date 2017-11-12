pragma solidity ^0.4.11;

import 'Submission.sol';

///Creating a Tournament and the functionality
contract Tournament {

    //Initialize Tournament Variables
    address public tournamentOwner;
    uint256 public startRoundTime;
    uint256 public roundEndTime;
    uint256 public reviewPeriod;
    uint256 public endOfTournamentTime;
    uint public bountyMTX;
    string public currentRound; //0
    string public maxRounds;
    string public metaDataPointer;
    //TODO create a wallet for each of the tournaments
    address tournamentOverride; //GOD
    bool submissions viewable; //Should we make this a dictionary with nrounds:true/false

//Make event for submission being made to the tournament, grab as many submissions

    //Initialize submission Variables
    address[] submissionList;
    string[] submissionNames;
    string[] submissionDetails;

    //Create a mapping with the people who created a submission so they can view the 
   // mapping(address => bool)

    endOfTournamentTime = roundEndTime + reviewPeriod;

    //Force roundCap to 1 round for alpha
    maxRounds = 1; 

    function createSubmission(tonOfInputs){
        address newSubmission = new Submission(tonOfInputs);
        submissionList.push(newSubmission);
    }



    //Tournament Constructor
    function Tournament(address tournamentOwner, uint256 startRoundTime, uint256 roundEndTime, uint256 reviewPeriod, 
        uint256 endOfTournamentTime, uint bountyMTX, string currentRound, string maxRounds, string metaDataPointer,
        address tournamentOverride){

        //Clean the inputs

        //Constructor assignments


    }

    }//end of contract




    )




/// TODO Edit everything below and retrofit the ballot example to the voting system as a signle voter for the tournament


// This is a type for a single proposal.
struct TournamentProposal {
    bytes32 name;   // short name (up to 32 bytes)
    uint voteCount; // number of accumulated votes


}

//     address public TournamentOwner;

//     // This declares a state variable that
//     // stores a `Voter` struct for each possible address.
//     mapping(address => Submitters) public submitters;

//     // A dynamically-sized array of `Proposal` structs.
//     Proposal[] public proposals;

//     /// Create a new ballot to choose one of `proposalNames`.
//     function Ballot(bytes32[] proposalNames) {
    //         chairperson = msg.sender;
    //         voters[chairperson].weight = 1;

    //         // For each of the provided proposal names,
    //         // create a new proposal object and add it
    //         // to the end of the array.
    //         for (uint i = 0; i < proposalNames.length; i++) {
        //             // `Proposal({...})` creates a temporary
        //             // Proposal object and `proposals.push(...)`
        //             // appends it to the end of `proposals`.
        //             proposals.push(Proposal({
            //                 name: proposalNames[i],
            //                 voteCount: 0
            //             }));
            //         }
            //     }

            //     // Give `voter` the right to vote on this ballot.
            //     // May only be called by `chairperson`.
            //     function giveRightToVote(address voter) {
                //         // If the argument of `require` evaluates to `false`,
                //         // it terminates and reverts all changes to
                //         // the state and to Ether balances. It is often
                //         // a good idea to use this if functions are
                //         // called incorrectly. But watch out, this
                //         // will currently also consume all provided gas
                //         // (this is planned to change in the future).
                //         require((msg.sender == chairperson) && !voters[voter].voted && (voters[voter].weight == 0));
                //         voters[voter].weight = 1;
                //     }

                //     /// Delegate your vote to the voter `to`.
                //     function delegate(address to) {
                    //         // assigns reference
                    //         Voter storage sender = voters[msg.sender];
                    //         require(!sender.voted);

                    //         // Self-delegation is not allowed.
                    //         require(to != msg.sender);

                    //         // Forward the delegation as long as
                    //         // `to` also delegated.
                    //         // In general, such loops are very dangerous,
                    //         // because if they run too long, they might
                    //         // need more gas than is available in a block.
                    //         // In this case, the delegation will not be executed,
                    //         // but in other situations, such loops might
                    //         // cause a contract to get "stuck" completely.
                    //         while (voters[to].delegate != address(0)) {
                        //             to = voters[to].delegate;

                        //             // We found a loop in the delegation, not allowed.
                        //             require(to != msg.sender);
                        //         }

                        //         // Since `sender` is a reference, this
                        //         // modifies `voters[msg.sender].voted`
                        //         sender.voted = true;
                        //         sender.delegate = to;
                        //         Voter storage delegate = voters[to];
                        //         if (delegate.voted) {
                            //             // If the delegate already voted,
                            //             // directly add to the number of votes
                            //             proposals[delegate.vote].voteCount += sender.weight;
                            //         } else {
                                //             // If the delegate did not vote yet,
                                //             // add to her weight.
                                //             delegate.weight += sender.weight;
                                //         }
                                //     }

                                //     /// Give your vote (including votes delegated to you)
                                //     /// to proposal `proposals[proposal].name`.
                                //     function vote(uint proposal) {
                                    //         Voter storage sender = voters[msg.sender];
                                    //         require(!sender.voted);
                                    //         sender.voted = true;
                                    //         sender.vote = proposal;

                                    //         // If `proposal` is out of the range of the array,
                                    //         // this will throw automatically and revert all
                                    //         // changes.
                                    //         proposals[proposal].voteCount += sender.weight;
                                    //     }

                                    //     /// @dev Computes the winning proposal taking all
                                    //     /// previous votes into account.
                                    //     function winningProposal() constant
                                    //             returns (uint winningProposal)
                                    //     {
                                        //         uint winningVoteCount = 0;
                                        //         for (uint p = 0; p < proposals.length; p++) {
                                            //             if (proposals[p].voteCount > winningVoteCount) {
                                                //                 winningVoteCount = proposals[p].voteCount;
                                                //                 winningProposal = p;
                                                //             }
                                                //         }
                                                //     }

                                                //     // Calls winningProposal() function to get the index
                                                //     // of the winner contained in the proposals array and then
                                                //     // returns the name of the winner
                                                //     function winnerName() constant
                                                //             returns (bytes32 winnerName)
                                                //     {
                                                    //         winnerName = proposals[winningProposal()].name;
                                                    //     }
// }