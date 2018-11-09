pragma solidity ^0.4.23;

/**
 * Let's make an interface that allows contracts to delegate state variable
 * value control to common theory instances.
 **/
interface ControlDelegated {
  // The address of the common theory contract control has been delegated to.
  function commonAddress() external view returns (address);
}

contract CommonHosting is ControlDelegated {

  address _commonAddress;

  function commonAddress() external view returns (address) {
    return _commonAddress;
  }

  /**
   * A domain that is being hosted. The dnslinked ipfs file or directory will
   * be pinned on common hosting machines as long as it's aggregate size is less
   * than 50 mb (open to change).
   *
   * Each subdomain is a separate entry in the system. dnslink can be used to
   * pin custom content per subdomain.
   *
   * https://docs.ipfs.io/guides/concepts/dnslink/
   **/
  struct HostedDomain {
    string name;
    uint256 lastPaymentTimestamp;
    uint256 lastPaymentAmount;
    uint256 lastHostRate;
    address creator;
  }

  /**
   * The wei/second cost of pinning the IPFS contents of a domain.
   *
   * Defaults to 0.1 eth/year
   *
   * 100000000000000000 / (365 * 24 * 60 * 60)
   **/
  uint256 public hostRate = 3170979198;

  /**
   * The max size of the object that can be pinned to storage.
   *
   * Default: 50 MB
   **/
  uint256 public bytesPerDomain = 1024 * 1024 * 50;

  HostedDomain[] public domains;

  constructor() public {}

  /**
   * Add a domain to the common hosting contract.
   **/
  function storeDomain(string domain) public payable {
    domains.push(HostedDomain({
      name: domain,
      lastPaymentTimestamp: block.timestamp,
      lastPaymentAmount: msg.value,
      lastHostRate: hostRate,
      creator: msg.sender
    }));
  }

  /**
   * Determine if a domain is hosted and paid up.
   *
   * TXT records should still be verified on the server to ensure that the
   * address controlling the entry controls the domain via ethlink.
   **/
  function isDomainHosted(string domain) public view returns (bool) {
    for (uint256 x = 0; x < domains.length; x++) {
      if (!stringsEqual(domain, domains[x].name)) continue;
      return domains[x].lastPaymentTimestamp + domains[x].lastPaymentAmount / domains[x].lastHostRate > block.timestamp;
    }
    return false;
  }

  /**
   * Compare string contents
   **/
  function stringsEqual(string _s1, string _s2) public pure returns (bool) {
    bytes memory str1 = bytes(_s1);
    bytes memory str2 = bytes(_s2);
    if (str1.length != str2.length) return false;
    // Strings are guaranteed to be same length
    for (uint256 x = 0; x < str1.length; x++) {
      if (str1[x] != str2[x]) return false;
    }
    return true;
  }

  function domainCount() public view returns (uint) {
    return domains.length;
  }

}
