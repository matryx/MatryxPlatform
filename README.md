# Matryx Alpha Source Code v1 ![alt text](https://matryx.ai/static/img/Matryx_Black_Full_Logo.png "Matryx Logo")
[![Travis](https://img.shields.io/travis/rust-lang/rust.svg)]()
[![Jenkins coverage](https://img.shields.io/jenkins/c/https/jenkins.qa.ubuntu.com/view/Utopic/view/All/job/address-book-service-utopic-i386-ci.svg)]()
[![Jenkins tests](https://img.shields.io/jenkins/t/https/jenkins.qa.ubuntu.com/view/Precise/view/All%20Precise/job/precise-desktop-amd64_default.svg)]()
[![Telegram](https://img.shields.io/badge/chat-Telegram-blue.svg)]()

## Introduction

> [Matryx.ai](https://www.matryx.ai): 
The Collaborative Research and Development Engine Optimized for Virtual Reality Interfaces

## How to use the platform
In our first iteration we focused on end-to-end development for the platform across many layers. From our Matryx ethereum private chain to our backend MatryxOracle system to our VR Interfaces. 
In the next release, we will be working towards our long term architecture to be put in place and thoroughly tested across the full integration. 

Our lead Matryx Architect, Max, made a great medium article posting on how to use the first alpha release of the Matryx Platform that focuses on integration with our Virtual Reality Mathematics tool, [Calcflow](http://calcflow.io/).

A link to the article directly can be found [here](https://blog.matryx.ai/matryx-alpha-a-how-to-guide-b6b5b9ffcca4)

![Calcflow](https://github.com/matryx/matryx-alpha-source/blob/master/Calcflow_mtx.gif)

## Build, Deploy, and Test the Platform

### Launching the Platform
Specify the network configuration in the truffle.js file. Ours is originally pointed to localhost:8545 which is common for TestRPC/Ganache-CLI.

Make sure your have TestRPC or Ganache-CLI installed and run it a different tab.

>`truffle migrate`

This will move the platform on to your network. You can then interact with the contract by attaching to it using truffle console.
>`truffle console`

From there, when you type 'MatryxPlatform', it will recognize the contract and you can start to call functions with ease.


### Testing the Platform
An extremely important part of the platform is testing to make sure it is not compromised. Luckily for this iteration, we are focused solely on end-to-end integration, but in the following releases we have already started implementing unit and functional testing paired with code coverage reports.

Check out our develop branch to see the latest pushes to the platform, but beware, it is an unstable build as we are actively building on it everyday.


