Participating in a Tournament
=============================

Creating a Submission
^^^^^^^^^^^^^^^^^^^^^

To create a submission, you will first need to assemble all of your submission details and content as follows:

.. code-block:: Solidity

    struct SubmissionData
    {
        bytes32[3] title;
        bytes32[2] descriptionHash;
        bytes32[2] fileHash;
        uint256 timeSubmitted;
        uint256 timeUpdated;
    }

Here you have the opportunity to cite any contributors or references in your submission and specify the intended reward distribution among all the contributors (expressed as a percentage or a proportion). This information should be included into the submission as follows:

.. code-block:: Solidity

    struct ContributorsAndReferences
    {
        address[] contributors;
        uint256[] contributorRewardDistribution;
        address[] references;
    }

.. note:: The contributors and contributor reward distribution arrays must have the same number of entries.

This is the ``createSubmission`` function signature:

.. code-block:: Solidity

	function createSubmission(submissionData, contributorsAndReferences)

Editing your Submissions
^^^^^^^^^^^^^^^^^^^^^^^^

As long as the current round remains open, you are able to edit any submissions you have made. To modify the data of your submission, you can call the ``updateData`` function like this:

.. code-block:: Solidity

	mySubmission.updateData(submissionModificationData)

Where ``SubmissionModificationData`` is the following:

.. code-block:: Solidity

    struct SubmissionModificationData
    {
        bytes32[3] title;
        bytes32[2] descriptionHash;
        bytes32[2] fileHash;
    }

Similarly, you can update your submission's contributors and references with the following calls:

.. code-block:: Solidity

    mySubmission.updateContributors(contributorsModificationData)
    mySubmission.updateReferences(referencesModificationData)

Where ``ContributorsModificationData`` is

.. code-block:: Solidity

    struct ContributorsModificationData
    {
        address[] contributorsToAdd;
        uint256[] contributorRewardDistribution;
        uint256[] contributorsToRemove;
    }

and ``ReferencesModificationData`` is

.. code-block:: Solidity

    struct ReferencesModificationData
    {
        address[] referencesToAdd;
        uint256[] referencesToRemove;
    }

Exiting a Tournament
^^^^^^^^^^^^^^^^^^^^

You can choose to exit an ongoing tournament at any time. When you exit, you can claim the entry fee that you paid when you first entered the tournament with this call:

.. code-block:: Solidity

	tournament.collectMyEntryFee()

.. note:: If you later decide to enter the tournament again, you will have to pay the current tournament entry fee before you’re able to make any submissions.

If a tournament you are currently participating in happens to become Abandoned, you can collect your share of the remaining tournament bounty with the following call:

.. code-block:: Solidity

	tournament.withdrawFromAbandoned()

Your tournament entry fee will also be returned to you when you make this call.

