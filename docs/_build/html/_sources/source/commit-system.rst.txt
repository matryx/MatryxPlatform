The Matryx Commit System
========================

The commit system is a collaborative content and IP tracking tool that allows value to be assigned and distributed across sequences of innovation.
The commit system is comprised of individual commits, which are units of work containing an IPFS content hash and a self-determined value that indicates how much each commit is worth.
Additionally, commits can contain links to previous commits, allowing users to collaborate with each other and build up entire chains of work.


Creating your first Commit
^^^^^^^^^^^^^^^^^^^^^^^^^^

In order to create a new commit, you will first need to claim the hash that you are going to use for it on the system.
This is done by calling

.. code-block:: Solidity

	commit.claimCommit(commitHash)

Where ``commitHash`` is a hash that’s comprised of your public Ethereum address, an IPFS hash of the content of your commit, and some salt used to encrypt the commit’s contents.

The reason you have to claim a commit hash before actually creating the commit is to prevent frontrunning attacks.
If a malicious actor were monitoring the system when you try to create the commit, they could potentially steal and take ownership of your commit content if they send the same transaction as you and their transaction gets mined first.
The ``claimCommit`` function exists to prevent this kind of attack. Once you have claimed a commit hash, the system knows that this particular hash belongs to you.
So, when you send the transaction to create the commit and actually reveal the commit’s content, no malicious actor can frontrun the transaction and steal your work.

That said, you can create your commit by calling

.. code-block:: Solidity

	commit.createCommit(parentHash, isFork, salt, content, value)

``Salt`` and ``content`` are the same hashes that you used to claim your commit.
``Value`` is a user-specified amount that indicates how much you think your commit is worth.
The first two fields, ``parentHash`` and ``isFork`` are used whenever you want to work off of someone else’s commit.
We will now explain how this collaboration process takes place.


Groups and Collaboration
^^^^^^^^^^^^^^^^^^^^^^^^

Commit groups are used to allow people to team up and work freely off of each other's commits.
In order to make a commit off of a parent commit, you must either be in the parent commit’s group, or fork off of the commit and start working with a new group.

To add a new user (or multiple users) to your group, you can call these two functions, respectively:

.. code-block:: Solidity

	commit.addGroupMember(commitHash, user)
	commit.addGroupMembers(commitHash, users)

Where ``commitHash`` is the hash of the commit in the chain that the new user wants to contribute to.

.. warning:: Group members cannot be removed from the group after you have added them. You should only add to your group users that you trust.

Any group member can add you to their group.
Once you become a part of the group, you will be able to make new commits along the same commit chain without having to pay for each of the commits made by your group members.
To create a commit off of another commit by someone in your group, you call the ``createCommit`` function and pass the hash of their commit as your ``parentHash``.
Since you are working in the same group, ``isFork`` should be ``false``.


Forking Commits
^^^^^^^^^^^^^^^

The process of forking off of a commit is similar to that of creating a new commit. 
First, you need to claim a commit hash using the same claim function:

.. code-block:: Solidity

	commit.claimCommit(commitHash)

Then, you create your commit:

.. code-block:: Solidity

	commit.createCommit(parentHash, isFork, salt, content, value)

Now, ``parentHash`` is the hash of the commit you want to fork, and ``isFork`` should be ``true``.

When you fork off of a commit, you are buying the right to use the entire previous chain of work for your own line of work that you are initiating at this point. 
The new commit that you create will represent a new starting point, and you will be the only user in the group (until you decide to add more people). 
After the fork, you will be able to work off of your commit freely, as you now have the right to use the previous line of work before the fork and the work that you and your group members add from that point on.

To fork off of a commit, you have to compensate the owners of commits in the chain for their contributions. 
The cost of a fork is the sum of the value of the commits in the line of work up until that point. 
Therefore, before you fork, you should make sure that you have approved at least that many MTX tokens.

.. note:: Anyone can fork a commit. You do not have to be in a commit’s group in order to fork the commit.
