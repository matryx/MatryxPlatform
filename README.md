![logo](https://github.com/matryx/matryx-alpha-source/blob/master/assets/Matryx-Logo-Black-1600px.png)

## Introduction

> [matryx.ai](https://www.matryx.ai): A Collaborative Research and Development Platform

## Platform Logic

**Matryx** consists of 3 major contracts: **MatryxSystem**, **MatryxPlatform**, and **MatryxTrinity**.

**MatryxSystem**
- All released versions of the Platform
- All used libraries addresses
- All relevant data needed to transform function signatures for forwarding calls

**MatryxPlatform**
- Contains all data for Tournament, Rounds, Submission, and Users
- Forwards calls from MatryxTrinity contracts to the relevant libraries

**MatryxTrinity**
- Encompasses MatryxTournament, MatryxRound, and MatryxSubmission
- Forwards calls to MatryxPlatform

When a call is made on a **MatryxTrinity** contract, such as **MatryxTournament**, **MatryxTrinity** forwards the call to **MatryxPlatform**, inserting `msg.sender` into the calldata so the original caller doesn't get lost. **MatryxPlatform** then looks up information from **MatryxSystem** to get the current library for that function and version of the Platform. It then uses this information to transform the calldata again, inserting state data from the Platform so that the library has access to Tournament, Round, Submission, and User data.

For every library method in **Matryx**, **MatryxSystem** stores function signature transformation data to modify forwarded calls and be able to insert **MatryxPlatform** `storage` slots into calldata. This enables the libraries to modify **MatryxPlatform**'s state while keeping the outwardly facing contract method signatures simple.

An example of this logic:

    call to MatryxTournament.getTitle
    => call to MatryxPlatform
    => call to MatryxSystem for lookup
    => delegatecall to LibTournament.getTitle (inserting Platform `storage` data)

---

We set up the **Matryx** system like this to enable upgradeability, as well as to minimize gas costs of creating Tournaments, Rounds, and Submissions.


## Testing Matryx locally with `truffle console`

1. Install dependencies and start ganache
    ```
    npm i
    ./ganache-local.sh
    ```

2. Then in a new window, enter the truffle console
    ```
    truffle console
    ```

3. The following commands are all executing inside truffle console
    ```
    migrate --reset
    .load setup
    ```

4. Next, set up the token contract and mint the first 2 accounts some MTX tokens
    ```
    token = contract(network.tokenAddress, MatryxToken);0
    token.setReleaseAgent(network.accounts[0])
    token.releaseTokenTransfer()
    token.mint(network.accounts[0], toWei(1e6))
    token.mint(network.accounts[1], toWei(1e6))
    ```

5. Next, enter Matryx and create a Tournament.

    **Note**: `stb` is a helper method to convert a string into `bytes32`, or `bytes32[n]`

    **Note**: In this minimal version of Matryx, Round start, end, and review are not being used yet. This is why they are just set to "1, 2, 3"
    ```
    p.enterMatryx()
    token.approve(p.address, toWei(100))
    tData = [stb('title', 3), stb('category'), stb('descHash', 2), stb('fileHash', 2), toWei(100), toWei(2)]
    rData = [1, 2, 3, toWei(10)]
    p.createTournament(tData, rData)
    p.getTournaments().then(ts => t = contract(ts.pop(), IMatryxTournament));0
    ```

6. Switch accounts, enter Matryx, approve the entry fee, and enter the Tournament
    ```
    token.accountNumber = 1
    p.accountNumber = 1
    t.accountNumber = 1
    p.enterMatryx()
    token.approve(t.address, toWei(2))
    t.enterTournament()
    ```

7. Create a Submission on the Tournament
    ```
    sData = [stb('title', 3), stb('descHash', 2), stb('fileHash', 2)]
    t.createSubmission(sData)
    t.getRounds().then(rs => r = contract(rs.pop(), IMatryxRound));0
    r.getSubmissions().then(ss => s = contract(ss.pop(), IMatryxSubmission));0
    ```

8. Switch back to the first account and select the Submission as a winner
    ```
    t.accountNumber = 0
    t.selectWinners([[s.address], [1]], rData)
    ```

9. Finally, check the balance of your Submission. You should see it was rewarded 10 MTX
    ```
    token.balanceOf(s.address).then(fromWei)
    ```
---
-The Matryx Team
