pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/math/SafeMath.sol";
import "../libraries/math/SafeMath128.sol";
import "../interfaces/IMatryxToken.sol";
import "../interfaces/IMatryxPeer.sol";
import "../interfaces/IMatryxPlatform.sol";
import "../interfaces/factories/IMatryxPeerFactory.sol";
import "../interfaces/factories/IMatryxTournamentFactory.sol";
import "../interfaces/IMatryxTournament.sol";
import "../interfaces/IMatryxRound.sol";
import "../interfaces/IMatryxSubmission.sol";
import "./Ownable.sol";

/// @title MatryxPlatform - The Matryx platform contract.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract MatryxPlatform is Ownable {
    using SafeMath for uint256;
    using SafeMath128 for uint128;

    // TODO: condense and put in structs
    // Matryx Addresses
    address public matryxTokenAddress;
    address public matryxPeerFactoryAddress;
    address public matryxTournamentFactoryAddress;
    address public matryxSubmissionFactoryAddress;
    address public matryxRoundLibAddress;

    //Contract Signatures to addresses
    mapping(bytes32=>address) private contracts;

    address[] public allTournaments;

    // Category Data
    bytes32[] public categoryList;
    mapping(bytes32=>bool) categoryExists;
    mapping(bytes32=>address[]) categoryToTournamentList;
    mapping(bytes32=>mapping(address=>bool)) tournamentExistsInCategory;
    mapping(bytes32=>uint256) emptyCountByCategory;
    mapping(address=>CategoryInfo) tournamentAddressToCategoryInfo;

    //Peer Mappings
    mapping(address=>bool) public peerExists;
    mapping(address=>address) public ownerToPeerAndPeerToOwner;
    mapping(address=>mapping(address=>bool)) addressToOwnsSubmission;

    // Tournament and Submission Mappings
    mapping(address=>bool) tournamentExists;
    mapping(address=>bool) submissionExists;
    mapping(address=>address[]) ownerToTournamentArray;
    mapping(address=>mapping(address=>bool)) entrantToOwnsTournament;
    mapping(address=>address[]) ownerToSubmissionArray;
    mapping(address=>mapping(address=>uint256_optional))  ownerToSubmissionToSubmissionIndex;

    // Hyperparams
    uint256_optional submissionGratitude = uint256_optional({exists: true, value: 2*10**17});

    /*
    * Structs
    */

    struct uint256_optional
    {
        bool exists;
        uint256 value;
    }

    struct CategoryInfo
    {
        uint256 index;
        bytes32 category;
    }

    /*
    * Events
    */
    event TournamentCreated(bytes32 _discipline, address _owner, address _tournamentAddress, bytes32[3] _tournamentName, bytes32[2] _descriptionHash, uint256 _MTXReward, uint256 _entryFee);
    event TournamentOpened(address _tournamentAddress, bytes32 _tournamentName_1, bytes32 _tournamentName_2, bytes32 _tournamentName_3, bytes32 _externalAddress_1, bytes32 _externalAddress_2, uint256 _MTXReward, uint256 _entryFee);
    event TournamentClosed(address _tournamentAddress, uint256 _finalRoundNumber, uint256 _MTXReward);
    event UserEnteredTournament(address _entrant, address _tournamentAddress);
    event QueryID(string queryID);

    constructor(address _matryxTokenAddress, address _matryxPeerFactoryAddress, address _matryxTournamentFactoryAddress, address _matryxSubmissionFactoryAddress) public
    {
        matryxTokenAddress = _matryxTokenAddress;
        matryxPeerFactoryAddress = _matryxPeerFactoryAddress;
        matryxTournamentFactoryAddress = _matryxTournamentFactoryAddress;
        matryxSubmissionFactoryAddress = _matryxSubmissionFactoryAddress;
    }


    /// @dev Allows tournaments to invoke tournamentClosed events on the platform.
    /// @param _finalRoundNumber Index of the round containing the winning submission.
    function invokeTournamentClosedEvent(uint256 _finalRoundNumber, uint256 _MTXReward) public onlyTournament
    {
        emit TournamentClosed(msg.sender, _finalRoundNumber, _MTXReward);
    }

    /*
    * Modifiers
    */
    modifier onlyTournament {
        require(tournamentExists[msg.sender]);
        _;
    }

    modifier onlyTournamentOrTournamentLib {
        bool isTournament = tournamentExists[msg.sender];
        bool isTournamentLib = getContractAddress(keccak256("LibTournamentEntrantMethods")) == msg.sender;

        require(isTournament || isTournamentLib);
        _;
    }

    modifier onlySubmission{
        require(submissionExists[msg.sender]);
        _;
    }

    modifier onlyPeerLinked(address _sender) {
        require(hasPeer(_sender));
        _;
    }

    modifier onlyTournamentOwnerOrPlatform(address _tournamentAddress){
        require(msg.sender == _tournamentAddress || entrantToOwnsTournament[msg.sender][_tournamentAddress] || msg.sender == address(this));
        _;
    }

    modifier notOwner(address _tournamentAddress) {
        require(entrantToOwnsTournament[msg.sender][_tournamentAddress] == false);
        _;
    }

    /*
    * State Maintenance Methods
    */

    /// @dev Sets an address for a contract the platform should know about.
    /// @param _nameHash Keccak256 hash of the name of the contract to give an address to.
    /// @param _contractAddress Address to be assigned for the given contract name.
    function setContractAddress(bytes32 _nameHash, address _contractAddress) public onlyOwner {
        contracts[_nameHash] = _contractAddress;
    }

    /// @dev explicitly set the MatryxToken address
    /// @param _matryxTokenAddress address of Matryx Token 
    function setTokenAddress(address _matryxTokenAddress) public onlyOwner {
        matryxTokenAddress = _matryxTokenAddress;
    }

    /// @dev Gets the address of a contract the platform knows about.
    /// @param _nameHash Keccak256 hash of the name of the contract to look for.
    /// @return Address of the contract with the designated name.
    function getContractAddress(bytes32 _nameHash) public returns (address contractAddress) {
        return contracts[_nameHash];
    }

    /// @dev Updates tournament ownership data.
    /// @param _owner address of the owner. 
    /// @param _tournament address of the tournament. 
    function updateUsersTournaments(address _owner, address _tournament) internal {
        ownerToTournamentArray[_owner].push(_tournament);
        entrantToOwnsTournament[_owner][_tournament] = true;
    }

    /// @dev Updates submission mappings. 
    /// @param _owner owner of the submission.
    /// @param _submission the submission address
    function updateSubmissions(address _owner, address _submission) public onlyTournamentOrTournamentLib {
        ownerToSubmissionToSubmissionIndex[_owner][_submission] = uint256_optional({exists:true, value:ownerToSubmissionArray[_owner].length});
        ownerToSubmissionArray[_owner].push(_submission);
        addressToOwnsSubmission[_owner][_submission] = true;
        submissionExists[_submission] = true;
    }

    /// @dev removes a submission from a tournament 
    /// @param _submissionAddress address of a particular MatryxSubmission
    /// @param _tournamentAddress address of a particular MatryxTournament
    function removeSubmission(address _submissionAddress, address _tournamentAddress) public {
        require(tournamentExists[_tournamentAddress]);
        require(submissionExists[_submissionAddress]);
        require(addressToOwnsSubmission[msg.sender][_submissionAddress]);

        address owner = Ownable(_submissionAddress).getOwner();
        uint256 submissionIndex = ownerToSubmissionToSubmissionIndex[owner][_submissionAddress].value;

        submissionExists[_submissionAddress] = false;
        delete ownerToSubmissionArray[owner][submissionIndex];
        delete ownerToSubmissionToSubmissionIndex[owner][_submissionAddress];

        IMatryxTournament(_tournamentAddress).removeSubmission(_submissionAddress, owner);
    }

    /// @dev Associated a tournament with a specific cateogory (sorting and filtering purposes)
    /// @param _tournamentAddress address of a particular MatryxTournament
    /// @param _category hash the category that the tournament belongs to
    function addTournamentToCategory(address _tournamentAddress, bytes32 _category) public onlyTournamentOwnerOrPlatform(_tournamentAddress) {
        if(categoryExists[_category] == false)
        {
            categoryList.push(_category);
            categoryExists[_category] = true;
        }

        if(tournamentExistsInCategory[_category][_tournamentAddress] == false)
        {
            tournamentExistsInCategory[_category][_tournamentAddress] = true;
            tournamentAddressToCategoryInfo[_tournamentAddress].category = _category;
            tournamentAddressToCategoryInfo[_tournamentAddress].index = (categoryToTournamentList[_category]).length;
            categoryToTournamentList[_category].push(_tournamentAddress);
        }
    }

    /// @dev Disassociated a tournament from a specific category 
    /// @param _tournamentAddress address of a particular MatryxTournament
    /// @param _category hash of the category that the tournament belongs to
    function removeTournamentFromCategory(address _tournamentAddress, bytes32 _category) public onlyTournamentOwnerOrPlatform(_tournamentAddress) {
        if(tournamentExistsInCategory[_category][_tournamentAddress])
        {
            // It's there! Let's remove it
            uint256 indexInCategoryList = tournamentAddressToCategoryInfo[_tournamentAddress].index;
            tournamentExistsInCategory[_category][_tournamentAddress] = false;
            categoryToTournamentList[_category][indexInCategoryList] = 0x0;
            tournamentAddressToCategoryInfo[_tournamentAddress].index = 0;
            emptyCountByCategory[_category] = emptyCountByCategory[_category].add(1);
        }
    }

    /// @dev Changes a tournament from one category to another
    /// @param _tournamentAddress address of a particular MatryxTournament
    /// @param _oldCategory hash of the category that the tournament previously belonged to
    /// @param _newCategory hash of the category that the tournament will now belong to 
    function switchTournamentCategory(address _tournamentAddress, bytes32 _oldCategory, bytes32 _newCategory) public onlyTournamentOwnerOrPlatform(_tournamentAddress){
        removeTournamentFromCategory(_tournamentAddress, _oldCategory);
        addTournamentToCategory(_tournamentAddress, _newCategory);
    }

    /*
     * Getters
     */ 

    function getTournamentsByCategory(bytes32 _category) external view returns (address[]){
        return categoryToTournamentList[_category];
    }

    function getCategoryCount(bytes32 _category) external view returns (uint256) {
        return categoryToTournamentList[_category].length.sub(emptyCountByCategory[_category]);
    }

    function getCategoryByIndex(uint256 _index) public view returns (bytes32){
        return categoryList[_index];
    }

    function getAllCategories() public view returns (uint256, bytes32[]){
        return (categoryList.length, categoryList);
    }

    /*
    * Tournament Entry Methods
    */

    /// @dev Enter the user into a tournament and charge the entry fee.
    /// @param _tournamentAddress Address of the tournament to enter into.
    /// @return _success Whether or not user was successfully entered into the tournament.
    function enterTournament(address _tournamentAddress) public onlyPeerLinked(msg.sender) notOwner(_tournamentAddress) returns (bool _success){
        require(tournamentExists[_tournamentAddress]);

        IMatryxTournament tournament = IMatryxTournament(_tournamentAddress);
        uint256 entryFee = tournament.getEntryFee();

        bool success = IMatryxToken(matryxTokenAddress).transferFrom(msg.sender, _tournamentAddress, entryFee);
        if(success)
        {
            success = tournament.enterUserInTournament(msg.sender);
            if(success)
            {
                emit UserEnteredTournament(msg.sender, _tournamentAddress);
            }
        }

        return true;
    }

    /*
    * Tournament Admin Methods
    */

    /// @dev Create a new tournament.
    /// @param tournamentData Data to populate the new tournament with. Includes:
    ///    category: Discipline the tournament falls under.
    ///    title: Name of the new tournament.
    ///    contentHash: Off-chain content hash of tournament details (ipfs hash)
    ///    initialBounty: Total tournament reward in MTX.
    ///    entryFee: Fee to charge participant upon entering into the tournament.
    /// @param roundData Data to populate the first round of the tournament with. Includes:
    ///    startTime: The start time (unix-epoch-based) of the first round.
    ///    endTime: The end time (unix-epoch-based) of the first round.
    ///    reviewPeriodDuration: The amount of the tournament owner has to determine the winners of the round.
    ///    bounty: The reward for the first round's winners.
    /// @return _tournamentAddress Address of the newly created tournament.
    function createTournament(LibConstruction.TournamentData tournamentData, LibConstruction.RoundData roundData) public returns (address _tournamentAddress){
        IMatryxTournamentFactory tournamentFactory = IMatryxTournamentFactory(matryxTournamentFactoryAddress);
        address newTournament = tournamentFactory.createTournament(tournamentData, roundData, msg.sender);

        emit TournamentCreated(tournamentData.category, msg.sender, newTournament, tournamentData.title, tournamentData.descriptionHash, tournamentData.initialBounty, tournamentData.entryFee);

        require(IMatryxToken(matryxTokenAddress).transferFrom(msg.sender, newTournament, tournamentData.initialBounty));
        IMatryxTournament(newTournament).sendBountyToRound(0, roundData.bounty);
        // update data structures
        allTournaments.push(newTournament);
        tournamentExists[newTournament] = true;
        updateUsersTournaments(msg.sender, newTournament);

        addTournamentToCategory(newTournament, tournamentData.category);

        return newTournament;
    }

    /*
    * Access Control Methods
    */

    function createPeer() public returns (address) {
        require(ownerToPeerAndPeerToOwner[msg.sender] == 0x0);
        IMatryxPeerFactory peerFactory = IMatryxPeerFactory(matryxPeerFactoryAddress);
        address peer = peerFactory.createPeer(msg.sender);
        peerExists[peer] = true;
        ownerToPeerAndPeerToOwner[msg.sender] = peer;
        ownerToPeerAndPeerToOwner[peer] = msg.sender;
    }

    function isPeer(address _peerAddress) public view returns (bool) {
        return peerExists[_peerAddress];
    }

    function hasPeer(address _sender) public view returns (bool) {
        return (ownerToPeerAndPeerToOwner[_sender] != 0x0);
    }

    function peerExistsAndOwnsSubmission(address _peer, address _reference) public view returns (bool) {
        bool isAPeer = peerExists[_peer];
        bool referenceIsSubmission = submissionExists[_reference];
        bool peerOwnsSubmission = addressToOwnsSubmission[ownerToPeerAndPeerToOwner[_peer]][_reference];

        return isAPeer && referenceIsSubmission && peerOwnsSubmission;
    }

    function peerAddress(address _sender) public view returns (address){
        return ownerToPeerAndPeerToOwner[_sender];
    }

    function isSubmission(address _submissionAddress) public view returns (bool){
        return submissionExists[_submissionAddress];
    }

    /// @dev Returns whether or not the given tournament belongs to the sender.
    /// @param _tournamentAddress Address of the tournament to check.
    /// @return _isMine Whether or not the tournament belongs to the sender.
    function getTournament_IsMine(address _tournamentAddress) public view returns (bool _isMine) {
        require(tournamentExists[_tournamentAddress]);
        Ownable tournament = Ownable(_tournamentAddress);
        return (tournament.getOwner() == msg.sender);
    }

    /*
    * Setter Methods
    */

    /// @dev              Set the relative amount of MTX to be delivered to a submission's
    ///                   references
    /// @param _gratitude Weight from 0 to 1 (18 decimal uint) specifying enforced submission
    ///                   gratitude
    function setSubmissionGratitude(uint256 _gratitude) public onlyOwner {
        assert(_gratitude >= 0 && _gratitude <= (1*10**18));
        submissionGratitude = uint256_optional({exists: true, value: _gratitude});
    }

    event TimeStamp(uint256 time);

    function getNow() public view returns (uint256) {
        emit TimeStamp(now);
        return now;
    }

    /*
    * Getter Methods
    */

    function getTokenAddress() public view returns (address) {
        return matryxTokenAddress;
    }

    function getTournamentFactoryAddress() public view returns (address)
    {
        return matryxTournamentFactoryAddress;
    }

    /// @dev    Returns a weight from 0 to 1 (18 decimal uint) indicating
    ///         how much of a submission's reward goes to its references.
    /// @return Relative amount of MTX going to references of submissions under this tournament.
    function getSubmissionGratitude() public view returns (uint256)
    {
        require(submissionGratitude.exists);
        return submissionGratitude.value;
    }

    /// @dev    Returns addresses for submissions the sender has created.
    /// @return Address array representing submissions.
    function myTournaments() public view returns (address[])
    {
        return ownerToTournamentArray[msg.sender];
    }

    function mySubmissions() public view returns (address[])
    {
        return ownerToSubmissionArray[msg.sender];
    }

    /// @dev    Returns the total number of tournaments
    /// @return _tournamentCount Total number of tournaments.
    function tournamentCount() public view returns (uint256 _tournamentCount)
    {
        return allTournaments.length;
    }

    function getTournamentAtIndex(uint256 _index) public view returns (address _tournamentAddress)
    {
        require(_index >= 0);
        require(_index < allTournaments.length);
        return allTournaments[_index];
    }

    function getTournaments() public view returns (address[])
    {
        return allTournaments;
    }
}
