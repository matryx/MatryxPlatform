The Matryx Bounty System
========================

The Matryx Bounty system enables and incentivizes decentralized scientific collaboration in the form of tournaments and submissions, 
where all users participating in a tournament receive credit for their contributions, and the tournament bounty is rightfully distributed among the chosen winners.

Tournament and Round States
^^^^^^^^^^^^^^^^^^^^^^^^^^^

Each tournament in Matryx is subdivided into rounds, which are indexed incrementally. 
In each round, tournament participants make submissions to the tournament, and at the end of each round one or multiple submissions are selected by the tournament owner to be the winners of the round. 
The round winners then receive the allocated round reward.

A tournament can be in one of five possible states: ``NotYetOpen``, ``OnHold``, ``Open``, ``Closed``, or ``Abandoned``.

If a tournament is ``NotYetOpen``, then its first round has not started yet. 
If it is ``OnHold``, that means that the tournament has already started but the next upcoming round has yet to begin. 
``Open`` tournaments are the ones that are currently active: submissions are being made or reviewed. 
``Closed`` tournaments are no longer active; the tournament owner has decided to end the tournament, and all of the tournament’s bounty has been distributed among the various rounds’ winners. 
Lastly, a tournament becomes ``Abandoned`` if a round ends without receiving any submissions, or if the tournament owner fails to select winners before the end of the round’s review period.

You can check the state of a tournament at any time by calling

.. code-block:: Solidity

	tournament.getState()

A round can be in one of seven possible states: ``NotYetOpen``, ``Unfunded``, ``Open``, ``InReview``, ``HasWinners``, ``Closed``, or ``Abandoned``.

Rounds that have not started yet are ``NotYetOpen``. 
A round is ``Unfunded`` if it has already started but the tournament owner has not added any MTX to its bounty yet. 
``Open`` rounds are currently active; you can enter the round and make new submissions. 
If a round is ``InReview``, you can no longer make any more submissions (you’re going to have to wait until the next round!). 
This is the time when the tournament owner reviews all the submissions made to the round and selects the winners. 
A round is ``Closed`` after the ``InReview`` period ends. 
Lastly, a round becomes ``Abandoned`` if it reaches the end of its ``Open`` state without receiving any submissions.

You can check the state of any round at any time by calling

.. code-block:: Solidity

  tournament.getRoundState(roundIndex)

Entering and Exiting Tournaments
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To enter a tournament that you’d like to participate in, you can make the following call:

.. code-block:: Solidity

  tournament.enter()

Whenever you enter a tournament, you will have to pay the tournament entry fee designated by the tournament creator, so you will need to first approve at least that many MTX tokens. 
To check what a tournament’s entry fee is before entering, you can call

.. code-block:: Solidity

  tournament.getDetails()

You can choose to exit an ongoing tournament at any time with the following call:

.. code-block:: Solidity

  tournament.exit()

When you exit the tournament, the entry fee that you paid when you first entered will be returned to you automatically.

.. note:: If you later decide to enter the tournament again, you will have to pay the tournament entry fee again before making any submissions.

If a tournament you are currently participating in happens to become ``Abandoned``, you can collect your share of the remaining tournament bounty, as well as your original entry fee, with the following call:

.. code-block:: Solidity

  tournament.withdrawFromAbandoned()

Making your first Submission
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To create a submission, you must first enter the tournament that you want to participate in by calling 

.. code-block:: Solidity

  tournament.enter()

You can then create a submission in two ways: You can create a new commit and submit it to the tournament, or you can submit one of your previous commits.

To create a new commit, you first need to claim the commit hash:

.. code-block:: Solidity

  commit.claimCommit(commitHash)

Then, you can create the commit and submit it to a tournament using the following function:

.. code-block:: Solidity

  commit.createSubmission(tournament, content, parentHash, isFork, salt, commitContent, value)

Where ``tournament`` is the address of the tournament, ``content`` is the Submission content, 
and ``parentHash``, ``isFork``, ``salt``, ``commitContent``, and ``value`` are the data that corresponds to the commit you are creating.

Alternatively, if you want to submit a commit that already exists, you can simply call:

.. code-block:: Solidity

  tournament.createSubmission(content, commitHash)

Where ``content`` is the content of your submission and ``commitHash`` is the hash of your commit.

Checking Commit Balances
^^^^^^^^^^^^^^^^^^^^^^^^

If a commit receives some amount of MTX, the appropriate amount will be allocated to the commit on the Matryx platform. 
To check the current allocated balance of any commit, you can call

.. code-block:: Solidity

  commit.getCommitBalance(commitHash)

Collecting your Reward
^^^^^^^^^^^^^^^^^^^^^^

When a commit in your line of work receives a reward from winning a tournament, you can withdraw your share of the reward by calling: 

.. code-block:: Solidity

  commit.withdrawAvailableReward(commitHash)

To check the reward that any user is entitled to for any particular commit, you can call

.. code-block:: Solidity

  commit.getAvailableRewardForUser(userAddress)

After you withdraw your reward, your available reward for that particular commit goes down to 0.

The share of the reward that is allocated to each commit owner in a commit chain is proportional to the total value of the commits that they created. 
Therefore, when a commit wins a tournament, everyone who contributed a piece of work used by the winning commit receives compensation for their contributions.

Creating your own Tournament
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To create a tournament, you can call the ``createTournament`` function on the platform as follows:

.. code-block:: Solidity

  platform.createTournament(tournamentDetails, roundDetails)

Where ``tournamentDetails`` and ``roundDetails`` are:

.. code-block:: Solidity

  struct TournamentDetails
  {
      string content;
      uint256 bounty;
      uint256 entryFee;
  }

  struct RoundDetails
  {
      uint256 start;
      uint256 duration;
      uint256 review;
      uint256 bounty;
  }


These structs contain information about the tournament that you are about to create and the first round that will kick off when the tournament begins. 
You can add more funds to the tournament bounty at any point, but you cannot remove funds from it after you make the ``createTournament`` call, so choose your initial bounty wisely!

Similarly, you cannot remove funds from the share of the tournament bounty you assign to the first round, and you won’t be able to edit the round details after the round has started. 
Be sure to enter a reasonable amount of time (in seconds) for the round’s ``start`` time and ``duration``, as well as its ``review`` period. 
You’ll need some time to look over the submissions and choose your round winners before the review period ends!

.. note:: The tournament and round bounty will be visible to any users looking to enter your tournament, as well as the tournament and round details.

Updating Tournament Details
^^^^^^^^^^^^^^^^^^^^^^^^^^^

To edit the data of your tournament, you can call the ``updateDetails`` function as follows:

.. code-block:: Solidity

  tournament.updateDetails(tournamentDetails)

Where ``tournamentDetails`` is the same data struct used to create the tournament originally. 
The ``bounty`` field, however, will not change when you try to modify the tournament’s data.

Adding to a Tournament Bounty
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Suppose you wanted to add MTX to a tournament’s bounty. You can call the ``addToBounty`` function as follows:

.. code-block:: Solidity

  tournament.addToBounty(amount)

This function transfers MTX to the specified tournament. To allocate these new funds to the current round, you can call the ``transferToRound`` function:

.. code-block:: Solidity

  tournament.transferToRound(amount)

The added MTX will now also be distributed to this round’s winners when it is time to reward their submissions.

.. warning:: Remember that you cannot remove funds from a tournament’s bounty after you’ve added them or remove funds from a round after it has already started.

Choosing Tournament Winners
^^^^^^^^^^^^^^^^^^^^^^^^^^^

To get all the submissions made to a round, you can call

.. code-block:: Solidity

  tournament.getRoundInfo(roundIndex)

Round info contains all the hashes of all the submissions made to the round. To view the contents of each submission, you can call

.. code-block:: Solidity

  platform.getSubmission(submissionHash)

To choose your round winners, you can call ``selectWinners`` on the tournament as follows:

.. code-block:: Solidity

  tournament.selectWinners(winnersData, roundDetails)

Where ``winnersData`` is:

.. code-block:: Solidity

  struct WinnersData
  {
      bytes32[] submissions;
      uint256[] distribution;
      uint256 action;
  }

Here, ``action`` represents an enumerated value from the following enum:

.. code-block:: Solidity

  enum SelectWinnerAction { DoNothing, StartNextRound, CloseTournament }

and ``RoundDetails`` are:

.. code-block:: Solidity

  struct RoundDetails
  {
      uint256 start;
      uint256 duration;
      uint256 review;
      uint256 bounty;
  }

In ``winnersData``, you can specify which submissions get rewarded and how much MTX is assigned to each one. 
The first parameter contains all the winning submissions’ hashes, and the second contains the reward each one will get, respectively, expressed as a percentage or a proportion of the total round bounty.

When selecting round winners, you have three options for how to proceed with the tournament: 
you can choose to wait until the end of the review period for the next round to start, to start the next round immediately after selecting the winners, or to close the tournament. 
The action you choose (0, 1 or 2, representing ``SelectWinnerAction.DoNothing``, ``SelectWinnerAction.StartNextRound`` and ``SelectWinnerAction.CloseTournament``, respectively) 
is passed as the third parameter of ``winnersData`` and indicates how you would like to proceed. 

If you choose to wait until the end of the review period (``DoNothing``), the next round will automatically be created as an identical copy of the last round, and it will begin once the current review period ends. 
If you choose to start the next round immediately when you select the winners (``StartNextRound``), the next round will be initialized with the round data that you provide and will begin immediately. 
If you choose to close the Tournament (``CloseTournament``), the remaining bounty unallocated to any round will be allocated to the current round and used to award ``winnersData.submissions``, 
and the Tournament will end.

.. warning:: Once you close the tournament, you can’t open it up again. Any remaining funds that might still be in the tournament’s balance will be evenly distributed among the last round’s winners when you decide to close the tournament.

.. warning:: If the round’s review period ends and you still have not chosen any winners, the tournament will be considered Abandoned, and any remaining funds in the tournament’s balance will be uniformly allocated to all of the round's participants for them to withdraw.
