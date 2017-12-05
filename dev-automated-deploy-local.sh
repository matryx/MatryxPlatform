#!/bin/bash

#TODO Fix a few things first


#Automated Development Deployment for Matryx Platform

mkdir Submissions
cp all files to Submissions minus Tournaments and MTXPlatform #TODO
cd Submissions
truffle compile
truffle migrate —reset
truffle var submissionsABI = Submissions.abi
truffle console.log(Submissions.abi) >> ../SubmissionsABI.txt

#Now do the Tournament
cd ..
rm -rf Submissions
mkdir Tournaments
cp all files to tournaments but submissions and MatryxPlatform #TODO
cd Tournaments
truffle compile
truffle migrate —reset
truffle var tournamentsABI = Tournaments.abi
truffle console.log(Tournaments.abi) >> ../TournamentABI.txt

var tournamentContractAttached = Tournament.at(Tournament.address)

truffle tournamentContractAttached.createSubmission(####)
truffle var submissionList =  tournamentContractAttached.listSubmissions()
var submissionContractAttached = web3.eth.contract(submissionsABI).at(submissionList) #Need to expand to more than one address TODO

cd ..

rm -rf Tournaments

#Compile the whole thang
truffle compile
truffle migrate —reset
#store the address for the MatryxPlatformContract
var matrixPlatformContractAddress = MatryxPlatformAlphaMain.address

#attach to the contract with a variable
var matryxPlatformContractAttached = MatryxPlatformAlphaMain.at(MatryxPlatformAlphaMain.address)

#Now you can call functions to test them
matryxPlatformContractAttached.createTournament(1)

var tournamentList = matryxPlatformContractAttached.getTournamentList()

#Now we need to link the Tournament Contracts
var tournamentContractAttached = web3.eth.contract(tournamentsABI).at(tournamentList)

