pragma solidity ^0.5.0;

library StringUtils {
  /**
   * Compare string contents
   **/
  function stringsEqual(string memory _s1, string memory _s2) public pure returns (bool) {
    bytes memory str1 = bytes(_s1);
    bytes memory str2 = bytes(_s2);
    if (str1.length != str2.length) return false;
    // Strings are guaranteed to be same length
    for (uint256 x = 0; x < str1.length; x++) {
      if (str1[x] != str2[x]) return false;
    }
    return true;
  }

  /**
   * Determines if a string contains another string
   **/
  function stringContains(string memory _haystack, string memory _needle) public pure returns (bool) {
    bytes memory haystack = bytes(_haystack);
    bytes memory needle = bytes(_needle);
    if (needle.length > haystack.length) return false;
    for (uint256 x = 0; x < haystack.length; x++) {
      if (haystack[x] != needle[0]) continue;
      for (uint256 y = 0; y < needle.length; y++) {
        if (haystack[x + y] != needle[y]) break;
        if (y == needle.length - 1) return true;
      }
    }
    return false;
  }

}
