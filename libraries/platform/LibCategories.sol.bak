pragma solidity ^0.4.23;

library LibCategories
{
    address[] public allTournaments;
    bytes32 public hashOfTopCategory;
    bytes32 public hashOfLastCategory;
    mapping(uint256=>bytes32) public  topCategoryByCount;
    mapping(bytes32=>category) public categoryIterator;
    string[] public categoryList;

    struct category
    {
        string name;
        uint128 count;
        bytes32 prev;
        bytes32 next;
        address[] tournaments;
    }

    function addTournamentToCategory(address _tournamentAddress, string _category) internal
    {
        bytes32 hashOfCategory = keccak256(_category);
        // If this is the first tournament in its category
        if(categoryIterator[hashOfCategory].count == 0)
        {
          // Push the new category to a list of categories
          categoryList.push(_category);

          // If its the first category ever
          if(hashOfTopCategory == 0x0)
          {
            // Update the top category pointer
            hashOfTopCategory = hashOfCategory;
            hashOfLastCategory = hashOfCategory;
            // Create a new entry in the iterator for it and don't store previous or next pointers
            categoryIterator[hashOfCategory] = category({name: _category, count: 1, prev: 0x0, next: 0x0, tournaments: new address[](0)});
            // Store the mapping from count 1 to this category
             topCategoryByCount[1] = hashOfCategory;
          }
          else
          {
            // If this is not the first category ever,
            // Create a new iterator entry, complete with a prev pointer to the previous last category
            categoryIterator[hashOfCategory] = category({name: _category, count: 1, prev: hashOfLastCategory, next: 0x0, tournaments: new address[](0)});
            // Update that previous last category's next pointer (there's one more after it now)
            categoryIterator[hashOfLastCategory].next = hashOfCategory;

            if( topCategoryByCount[1] == 0x0)
            {
               topCategoryByCount[1] = hashOfCategory;
            }
          }

          // Push to the tournaments list for this category
          categoryIterator[hashOfCategory].tournaments.push(_tournamentAddress);
          // Update the last category pointer
          hashOfLastCategory = hashOfCategory;
          return;
        }

        categoryIterator[hashOfCategory].tournaments.push(_tournamentAddress);

        uint256 categoryCount = categoryIterator[hashOfCategory].count;
        // If this category has the top relative count (category.prev.count > category.count):
        //  If category.next exists, the top category for our previous count becomes category.next,
        //  otherwise (category.next doesn't exist), the top category for our previous count
        //  we set to 0x0.
        // if( topCategoryByCount[categoryCount] == hashOfCategory)
        // {
        //   if(categoryIterator[hashOfCategory].next != 0x0)
        //   {
        //      topCategoryByCount[categoryCount] = categoryIterator[hashOfCategory].next;
        //   }
        //   else
        //   {
        //      topCategoryByCount[categoryCount] = 0x0;
        //   }
        // }

        uint128 newCount = categoryIterator[hashOfCategory].count + 1;
        categoryIterator[hashOfCategory].count = newCount;

        // If the top category for our new count is not defined, 
        // define it as this category.
        if( topCategoryByCount[newCount] == 0)
        {
           topCategoryByCount[newCount] = hashOfCategory;
        }

        // If the count of the category is now greater than the previous category
        // swap it with the top category of its count.
        if(categoryIterator[hashOfCategory].prev != 0x0)
        {
          if(categoryIterator[hashOfCategory].count > categoryIterator[categoryIterator[hashOfCategory].prev].count)
          {
            // define A as the top category of its count
            bytes32 hashOfTopA =  topCategoryByCount[categoryIterator[hashOfCategory].count-1];
            if(hashOfTopA == hashOfTopCategory)
            {
              hashOfTopCategory = hashOfCategory;
            }

            if(hashOfCategory == hashOfLastCategory)
            {
              //update pointer to hash of last category
              hashOfLastCategory = hashOfTopA;
            }

            //flip the two categories and rearrange the pointers
            category storage A = categoryIterator[hashOfTopA];
            category storage B = categoryIterator[hashOfCategory];

            bool adjacent = A.next == hashOfCategory;
            bytes32 Bprev = B.prev;
            bytes32 Anext = A.next;

            A.next = B.next;
            B.prev = A.prev;

            if(A.prev != 0x0)
            {
              categoryIterator[A.prev].next = hashOfCategory;
            }
            if(B.next != 0x0)
            {
              categoryIterator[B.next].prev = hashOfTopA;
            }
            
            if(adjacent)
            {
              A.prev = hashOfCategory;
              B.next = hashOfTopA;
            }
            else
            {
              A.prev = Bprev;
              B.next = Anext;
              if(Bprev != 0x0)
              {
                categoryIterator[Bprev].next = hashOfTopA;
              }
              if(Anext != 0x0)
              {
                categoryIterator[Anext].prev = hashOfCategory;
              }
            }
        }
    }

  //Get the index-th topmost category (index 0 returns the overall top category)
  function getTopCategory(uint256 _index) external view returns (string)
  {
    bytes32 categoryHash = hashOfTopCategory;
    string storage categoryName  = categoryIterator[categoryHash].name;

    for(uint256 i = 1; i <= _index; i++)
    {
      categoryHash = categoryIterator[categoryHash].next;
      categoryName = categoryIterator[categoryHash].name;
    
      if(categoryHash == 0x0)
      {
        break;
      }
    }

    return categoryName;
  }

  function getTournamentsByCategory(string _category) external view returns (address[])
  {
    return categoryIterator[keccak256(_category)].tournaments;
  }

  function getCategoryCount(string _category) external view returns (uint256)
  {
    return categoryIterator[keccak256(_category)].count;
  }
}