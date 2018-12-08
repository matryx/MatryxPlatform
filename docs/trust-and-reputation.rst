Reputation System
=================

User Reputation
^^^^^^^^^^^^^^^

Every Matryx user has a number of potive and negative votes associated with their address that represents the number of positive or negative interactions that they have had on the platform.
These votes are only given by other Matryx platform users. To check a user's positive and negative vote count, you can make the following call to the MatryxUser contract:

.. code-block:: Solidity

	users.getVotes(userAddress)

This function returns a tuple, where the first component is the total number of positive votes for ``userAddress``, and the second component is the total number of negative votes.

Voting on Submissions as a Tournament Owner
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

During the winner selection process, the tournament owner has the option to give positive or negative votes to the submissions made to that round.
Positive and negative submission votes will also affect the submission owner's user reputation.
Negative votes should be given to any submissions that are completely unrelated to the tournament's specifications, any repeated submissions, or any submissions that would be considered to be spam.
To vote on a submission, you can make the following call:

.. code-block:: Solidity

    tournament.voteSubmission(submissionAddress, true)

The second parameter is a boolean value that indicates whether the vote is a positive vote (``true``) or a negative vote (``false``).

Voting on a Round as a Tournament Entrant
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

After the winner selection process, any round participants can vote on the current round based on the tournament owner's fairness on the winner selection process.
Similarly, any positive or negative round votes will also affect the tournament owner's user reputation.
Negative votes should only be given to a round if the tournament owner's winner selection process is unreasonable or clearly biased.
Positive votes should be given if the submissions selected to win the round seem fair and reasonable.
To vote on a round that you have participated in, you can make the following call:

.. code-block:: Solidity

    tournament.voteRound(roundAddress, true)

The second parameter here also indicates whether the vote is positive (``true``) or negative (``false``).

Flagging a Submission for Missing a Reference
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

As a Matryx user, you always have the ability to flag a sumbission if you believe that it is using your work without citing your submission as a reference.
You can flag a submission for missing a reference with the following call:

.. code-block:: Solidity

    submission.flagMissingReference(referenceAddress)

Where ``referenceAddress`` is the address of the submission that you believe is missing from the submission's references.
Note that you must be the owner of the reference in order to flag a submission for missing that reference.
Furthermore, the submission will only be flagged if the submission owner has in fact unlocked your submission's files and has permission to view them.
Adding a missing reference flag to a submission results in a negative vote for both the submission and the submission's owner.