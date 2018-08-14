pragma solidity ^0.4.23;

import "../math/SafeMath.sol";


library LibCategories
{
    using SafeMath for uint256;


    struct CategoriesData
    {
        category[] categoryList;
        mapping(bytes32=>uint256) categoryToIndex;
        mapping(bytes32=>bool) categoryExists;
    }

    struct category
    {
        uint256 count;
        address[] tournaments;
    }

    function addTournamentToCategory(LibCategories.CategoriesData storage data, address _tournamentAddress, bytes32 _category) public
    {
        // Add category if it doesn't already exist
        if (data.categoryExists[_category] == false)
        {
            //add category to mappings
            data.categoryExists[_category] = true;
            data.categoryToIndex[_category] = data.categoryList.length;

            //Creates the category to add in memory
            uint256 id = data.categoryList.length++;
            data.categoryList[id].count = 1;
            data.categoryList[id].tournaments.push(_tournamentAddress);
        }
        else
        {
            // Keep track of count and add tournament
            category storage currentCategory = data.categoryList[data.categoryToIndex[_category]];
            currentCategory.count = currentCategory.count.add(1);
            currentCategory.tournaments.push(_tournamentAddress);
        }
    }

    function removeTournamentFromCategory(LibCategories.CategoriesData storage data, bytes32 _category, address _tournamentAddress) public
    {
        //TODO - figure out how to remove tournaments from the array without leaving a bunch of 0s in it
    }

    function getTournamentsByCategory(LibCategories.CategoriesData storage data, bytes32 _category) public returns (address[])
    {
        return data.categoryList[data.categoryToIndex[_category]].tournaments;
    }

    function getCategoryCount(LibCategories.CategoriesData storage data, bytes32 _category) public returns (uint256)
    {
        return data.categoryList[data.categoryToIndex[_category]].count;
    }

}