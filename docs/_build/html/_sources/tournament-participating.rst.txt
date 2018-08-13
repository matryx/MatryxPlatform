Participating in a Tournament
=============================

Creating a Submission
^^^^^^^^^^^^^^^^^^^^^

To create a submission, you will first need to assemble all of your submission details and content as follows:

.. code-block:: Solidity

    struct SubmissionData
    {
        string title;
        address owner;
        bytes descriptionHash;
        bytes fileHash;
        bool isPublic;
    }

This is the ``createSubmission`` function signature:

.. code-block:: Solidity

	function createSubmission(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references, LibConstruction.SubmissionData submissionData) public onlyEntrant onlyPeerLinked(msg.sender) ifRoundHasFunds whileTournamentOpen returns (address _submissionAddress)

Here you have to opportunity to cite any contributors or references in your submission and specify the intended reward distribution among all the contributors (expressed as a percentage).

.. note:: The contributors and contributor reward distribution arrays must have the same number of entries.

Editing your Submissions
^^^^^^^^^^^^^^^^^^^^^^^^

As long as the current round remains open, you are able to edit any submissions you have made. The ``update`` function is called on the submission you want to change, and this is the function signature:

.. code-block:: Solidity

	function update(address[] _contributorsToAdd, uint128[] _contributorRewardDistribution, address[] _contributorsToRemove, LibConstruction.SubmissionModificationData _data)

Where ``SubmissionModificationData`` is the following:

.. code-block:: Solidity

    struct SubmissionModificationData
    {
        string title;
        address owner;
        bytes descriptionHash;
        bytes fileHash;
        bool isPublic;
    }

Exiting a Tournament
^^^^^^^^^^^^^^^^^^^^

You can choose to exit a tournament at any time as long as you haven’t made any submissions to a round that is still ongoing. When you exit, you can claim the entry fee that you paid when you first entered the tournament with this call:

.. code-block:: Solidity

	tournament.collectMyEntryFee()

.. note:: If you later decide to enter the tournament again, you will have to pay the current tournament entry fee before you’re able to make any submissions.

If a tournament you are currently participating in happens to become Abandoned, you can collect your share of the remaining tournament bounty with the following call:

.. code-block:: Solidity

	tournament.withdrawFromAbandoned()

