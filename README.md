![logo](https://github.com/matryx/matryx-alpha-source/blob/master/assets/Matryx-Logo-Black-1600px.png)

## Introduction

> [matryx.ai](https://www.matryx.ai): A Collaborative Research and Development Platform

## Platform Logic

**Matryx** consists of 3 major contracts: **MatryxSystem**, **MatryxPlatform**, and **MatryxForwarder**.

**MatryxSystem**
- Contains all released versions of the Platform
- Contains all used libraries addresses
- Contains all relevant data needed to transform function signatures for forwarding calls

**MatryxPlatform**
- Contains all data for Tournaments, Commits, and Submissions
- Forwards calls from MatryxForwarder contracts to the relevant libraries

**MatryxForwarder**
- Forwards calls to MatryxPlatform

When a call is made on a **MatryxForwarder** contract, such as **MatryxTournament**, **MatryxForwarder** forwards the call to **MatryxPlatform**, inserting `msg.sender` into the calldata so the original caller doesn't get lost. **MatryxPlatform** then looks up information from **MatryxSystem** to get the current library for that function and version of the Platform. It then uses this information to transform the calldata again, inserting state data from the Platform so that the library has access to Tournament, Commit, and Submission data.

For every library method in **Matryx**, **MatryxSystem** stores the function signature transformation data used to modify calldata. The calldata is modified by inserting **MatryxPlatform** `storage` slots for the delegatecall to the library method. This enables the libraries to modify **MatryxPlatform**'s state while keeping the outwardly facing contract method signatures simple.

An example of this logic:

    => call to MatryxTournament.getBalance
    => call to MatryxSystem to lookup Platform address
    => call to MatryxPlatform (inserting msg.sender address)
    => call to MatryxSystem to lookup forwarding info
    => delegatecall to LibTournament.getBalance (inserting Platform storage data)

An example of a MTX transfer between MatryxForwarder contracts:

    => call to MatryxTournament.transferTo
    => delegatecall to LibForwarder.transferTo
    => call to MatryxToken.transfer

---

We set up the **Matryx** system like this to enable upgradeability, as well as to minimize gas costs of creating Tournaments, Commits, and Submissions.


## Testing Matryx locally with `truffle console`

1. Install dependencies, remove the build folder, and start ganache
    ```
    npm i
    rm -r build/
    ./ganache-local.sh
    ```

2. Then in a new window, enter the truffle console
    ```
    truffle console
    ```

3. Execute the following commands inside truffle console
    ```
    migrate --reset
    .load setup
    ```

4. Lastly, you can test out the platform by running
    ```
    exec truffle/test.js
    ```



## Architecture Diagram

![architecture diagram](https://github.com/matryx/MatryxPlatform/blob/master/assets/ArchitectureDiagram.svg)


---
-The Matryx Team
