Participating in a Tournament
=============================

Creating a Submission
^^^^^^^^^^^^^^^^^^^^^

To create a submission, you will first need to assemble all of your submission data as follows:

.. code-block:: Solidity

    struct SubmissionData
    {
        bytes32[3] title;
        bytes32[2] descHash;
        bytes32[2] fileHash;
        uint256[] distribution;
        address[] contributors;
        address[] references;
    }

Here you have the opportunity to cite any contributors to your submission and specify the intended reward distribution among them (expressed as a percentage or a proportion). The first entry in the ``distribution`` array represents the percentage of the reward that will be assigned to the submission owner (yourself), and any subsequent entries represent the percentage of the reward that will be assigned to each of your contributors, in the same order as they appear in your ``contributors`` array.
You can also cite other Matryx submissions in your submission's ``references`` array by passing in their addresses.

.. note:: The ``distribution`` array will always have one more entry than your ``contributors`` array, since the first entry in the ``distribution`` array includes information about the submission owner.

.. note:: THe addresses in your ``references`` array must be existing submissions on the Matryx platform.

This is the ``createSubmission`` function call:

.. code-block:: Solidity

	tournament.createSubmission(submissionData)

You are now ready to start making original submissions to any Matryx tournament!

Editing your Submissions
^^^^^^^^^^^^^^^^^^^^^^^^

As long as the current round remains open, you are able to edit any submissions you have made in that round. To modify the data of your submission, you can call the ``updateDetails`` function as follows:

.. code-block:: Solidity

	mySubmission.updateDetails(submissionDetails)

Where ``submissionDetails`` is the following:

.. code-block:: Solidity

    struct SubmissionDetails
    {
        bytes32[3] title;
        bytes32[2] descHash;
        bytes32[2] fileHash;
    }

Similarly, you can add or remove contributors and references with the following calls:

.. code-block:: Solidity

    mySubmission.addContributorsAndReferences(contributors, distribution, references)
    mySubmission.removeContributorsAndReferences(contributors, references)

You can add or remove contributors and references to your submission at any time.

.. note:: The distribution values assigned to any contributors that you remove will be automatically removed from the distribution array as well.

Exiting a Tournament
^^^^^^^^^^^^^^^^^^^^

You can choose to exit an ongoing tournament at any time with the following call:

.. code-block:: Solidity

	tournament.exit()

When you exit the tournament, the entry fee that you paid when you first entered will be returned to you automatically.

.. note:: If you later decide to enter the tournament again, you will have to pay the current tournament entry fee before making any submissions.

If a tournament you are currently participating in happens to become Abandoned, you can collect your share of the remaining tournament bounty, as well as your original entry fee, with the following call:

.. code-block:: Solidity

	tournament.withdrawFromAbandoned()

Viewing Other Submissions
^^^^^^^^^^^^^^^^^^^^^^^^^

In order to incentivize open collaboration between participants on the Matryx platform, all submissions are viewable to Matryx entrants after the round review period is over. However, in order to prevent inter-round plagiarism or inadequate credit attribution between different participants, a user has to first unlock a submission's files in order to view them. The list of users that have unlocked a submission's files are stored on the Matryx platform. This ensures that, in the event of a dispute over the originality of a piece of work, the platform data can prove whether or not a user has at least viewed another user's submission files.

To see what other people have been working on, you can make the following call on any submission:

.. code-block:: Solidity

	submission.unlockFile()

The submission's file hash will then become available to you.

.. note:: The tournament owner doesn't need to unlock the files of any submission in their tournament to view them, since they will need to see the files in order to select the round's winners.