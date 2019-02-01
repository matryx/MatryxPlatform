The Matryx Bounty System
========================

The Matryx Bounty system enables and incentivizes decentralized scientific collaboration in the form of tournaments and submissions, where all users participating in a tournament receive credit for their contributions, and the tournament bounty is rightfully distributed among the chosen winners.

Tournament and Round States
^^^^^^^^^^^^^^^^^^^^^^^^^^^

Each tournament in Matryx is subdivided into rounds. In each round, tournament participants make submissions to the tournament. At the end of each round, one or multiple submissions are chosen by the tournament owner to be the winners of the round. Those winners then receive the allocated round reward.

A tournament can be in one of five possible states: ``NotYetOpen``, ``OnHold``, ``Open``, ``Closed``, or ``Abandoned``.

If a tournament is ``NotYetOpen``, then its first round has not started yet. If it is ``OnHold``, that means that the tournament has already started but the next upcoming round has yet to begin. Open tournaments are the ones that are currently active: submissions are being made or reviewed. Closed tournaments are no longer active; the tournament owner has decided to end the tournament, and all of the tournament’s bounty has been distributed among the various rounds’ winners. Lastly, a tournament becomes ``Abandoned`` if a round ends without receiving any submissions, or if the tournament owner fails to select winners before the end of the round’s review period.

You can check the state of a tournament at any time by calling

.. code-block:: Solidity
  tournament.getState()

A round can be in one of seven possible states: ``NotYetOpen``, ``Unfunded``, ``Open``, ``InReview``, ``HasWinners``, ``Closed``, or ``Abandoned``.

Rounds that have not started yet are ``NotYetOpen``. A round is ``Unfunded`` if it has already started but the tournament owner has not added any funds to its bounty yet. ``Open`` rounds are currently active; you can enter the round and make new submissions. If a round is ``InReview``, you can no longer make any more submissions (you’re going to have to wait until the next round!). This is the time when the tournament owner reviews all the submissions made to the round and selects the winners. A round is ``Closed`` after the ``InReview`` period ends. Lastly, a round becomes ``Abandoned`` if it reaches the end of its Open state without receiving any submissions.

You can check the state of any round at any time by calling

.. code-block:: Solidity
  round.getState()

Creating a Tournament
^^^^^^^^^^^^^^^^^^^^^

To create a tournament, call:

.. code-block:: Solidity
  platform.createTournament(tournamentData, roundData)

Where ``TournamentData`` and ``RoundData`` are:

.. code-block:: Solidity
  struct TournamentData
  {
      bytes32[3] title;
      bytes32 category;
      bytes32[2] descHash;
      bytes32[2] fileHash;
      uint256 bounty;
      uint256 entryFee;
  }

  struct RoundData
  {
      uint256 start;
      uint256 end;
      uint256 review;
      uint256 bounty;
  }

These structs contain all the necessary information to begin a tournament. The round data passed contains the parameters of the first round to be opened on the tournament. Tournament bounties are additive only; You can increase the tournament bounty at any time but cannot decrease it once it has been increased. Choose your bounty wisely!

Similarly, you cannot remove funds from the share of the tournament bounty you assign to the first round, and you won’t be able to edit the round details after the round has started. Be sure to enter a reasonable amount of time (in seconds) for the round’s start and end time, as well as its review period. You’ll need some time to look over the submissions and choose your round winners before the review period ends!

Note: The tournament and round bounty will be visible to any users looking to enter your tournament, as well as the tournament and round details.

Editing A Tournament
^^^^^^^^^^^^^^^^^^^^

To edit the data of your tournament, you can call the updateDetails function as follows:

.. code-block:: Solidity
  tournament.updateDetails(tournamentData)

Where ``tournamentData`` is the same data struct used to create the tournament originally. The bounty field, however, will not change when you try to modify the tournament’s data.

Increasing the Tournament Bounty
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Suppose you wanted to add MTX to a tournament’s bounty. You can call the addFunds function as follows:

.. code-block:: Solidity
  tournament.addFunds(1)

This function transfers funds to the specified tournament. To allocate these new funds to the current round, you can call the transferToRound function.

.. code-block:: Solidity
  tournament.transferToRound(1)

The added funds will now also be distributed to this round’s winners when it is time to reward their submissions.

Warning: Remember that you cannot remove funds from a tournament’s bounty after you’ve added them or remove funds from a round after it has already started.

Choosing Tournament Winners
^^^^^^^^^^^^^^^^^^^^^^^^^^^

To get all the submissions made to this round, you can call:

.. code-block:: Solidity
  round.getSubmissions()

To choose your round winners, you can call selectWinners on the tournament as follows:

.. code-block:: Solidity
  tournament.selectWinners(winnersData, roundData)

Where ``winnersData`` is:

.. code-block:: Solidity
  struct WinnersData
  {
      bytes32[] submissions;
      uint256[] distribution;
      uint256 action;
  }

Here, action represents an enumerated value from the following enum:

.. code-block:: Solidity
  enum SelectWinnerAction 
  { 
    DoNothing,
    StartNextRound,
    CloseTournament 
  }

and ``RoundData`` is the following struct:

.. code-block:: Solidity
  struct RoundData
  {
      uint256 start;
      uint256 end;
      uint256 review;
      uint256 bounty;
  }

In ``winnersData``, you can specify which submissions get rewarded and how much MTX is assigned to each one; the first parameter contains all the winning submissions’ hashes, and the second contains the reward each one will get, respectively, expressed as a percentage or a proportion of the total round bounty.

When selecting round winners, you have three options for how to proceed with the tournament: you can choose to wait until the end of the review period for the next round to start, to start the next round immediately after selecting the winners, or to close the tournament. The action you choose (0, 1 or 2, representing ``SelectWinnerAction.DoNothing``, ``SelectWinnerAction.StartNextRound`` and ``SelectWinnerAction.CloseTournament``, respectively) is passed as the third parameter of winnersData and indicates how you would like to proceed. 

If you choose to wait until the end of the review period (``DoNothing``), the next round will automatically be created as an identical copy of the last round. If you choose to start the next round immediately when you select the winners (``StartNextRound``), the next round will be initialized with the round data that you provide. If you choose to close the Tournament (``CloseTournament``), the remaining bounty unallocated to any round will be transferred to the current round and used to award winnersData.submissions, and the Tournament will end.

.. warning:: Once you close the tournament, you can’t open it up again. Any remaining funds that might still be in the tournament’s balance will be evenly distributed among the last round’s winners when you close the tournament.

.. warning:: If the round’s review period ends and you still have not chosen any winners, the tournament will be considered Abandoned, and any remaining funds in the tournament’s balance will be uniformly allocated to all tournament participants for them to withdraw.

To enter a tournament that you’d like to participate in, you can make the following call:

.. code-block:: Solidity
  tournament.enter()

Whenever you enter a tournament, you will have to pay the tournament entry fee designated by the tournament creator, so you need to first approve at least that many MTX tokens. To check a tournament’s entry fee before entering, you can call

.. code-block:: Solidity
  tournament.getEntryFee()

You can choose to exit an ongoing tournament at any time with the following call:

.. code-block:: Solidity
  tournament.exit()

When you exit the tournament, the entry fee that you paid when you first entered will be returned to you automatically.

.. note:: If you later decide to enter the tournament again, you will have to pay the current tournament entry fee before making any submissions.

If a tournament you are currently participating in happens to become ``Abandoned``, you can collect your share of the remaining tournament bounty, as well as your original entry fee, with the following call:

.. code-block:: Solidity
  tournament.withdrawFromAbandoned()

Making A Submission
^^^^^^^^^^^^^^^^^^^

To create a submission, you must first enter the tournament that you want to participate in. You can create a submission in two ways: 

.. code-block:: Solidity
  tournament.createSubmission(title, descriptionHash, commitHash)

Where ``title`` is the title of your submission, ``descriptionHash`` is an IPFS hash with text content for the description of your submission, and ``commitHash`` is a commit on the Matryx commit system.

Additionally, you can create a new commit and submit it to a tournament by calling:

.. code-block:: Solidity
  commitSystem.submitToTournament(tournamentAddress, title, descriptionHash, contentHash, value, parentHash, group)

Parameters include:
``tournamentAddress``:  Address of Tournament to submit to
``title``:              Title of the submission
``descriptionHash``:    IPFS hash of description of the submission
``contentHash``:        Hash of the commits content
``value``:              Author-determined value of the commit
``parentHash``:         Parent commit hash
``group``:              Name of the group for the commit

Checking Commit Balances
^^^^^^^^^^^^^^^^^^^^^^^^

If a commit receives some amount of MTX, the funds will initially be stored on the Matryx platform. To check the current allocated balance of any commit on the platform, you can call:

.. code-block:: Solidity
  platform.getCommitBalance(commitHash)

Collecting MTX
^^^^^^^^^^^^^^^

When a commit receives an MTX reward from winning a Tournament, someone must first call ``distributeReward`` to make the funds available to the commit owner and the owners of the commit’s ancestors: 

.. code-block:: Solidity
  commit.distributeReward(commitHash)

This calculates and allocates the reward to each commit owner, proportional to the total value of the commits that they created. The balance of the commit becomes 0 after calling this function, since the calculated value has now been allocated to each individual user address instead.

To get the balance that is allocated to each user address, you can call:

.. code-block:: Solidity
  platform.getBalanceOf(userAddress)

Finally, to have the tokens transferred to your account, call:

.. code-block:: Solidity
  platform.withdrawBalance()

Congrats! You may now use your MTX to place bounties on your own scientific inquiries. 