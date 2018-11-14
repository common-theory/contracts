pragma solidity ^0.5.0;

/**
 * The CommonSyndicate contract
 *
 * A way for distributed groups of people to work together and come to consensus
 * on use of funds.
 *
 * syndicate - noun
 * a group of individuals or organizations combined to promote some common interest
 **/

/**
 * Things it would be cool to be able to do:
 *   - Vote to move syndicate money into DAI
 *   - Use bancor liquidity to auto diversify with ERC20 tokens upon vote
 **/

contract CommonSyndicate {

  mapping (address => uint256) public balances;

  bool public contractUpdated = false;
  address public newContract;

  /**
   * Always settle payments forward in time, keep track of the last settled to
   * reduce gas (loop iterations) as more payments are receieved.
   **/
  uint256 public lastSettledPayment = 0;

  struct Payment {
    address sender;
    uint256 weiValue;
    bool settled;
  }

  uint256 public totalSyndicateValue = 0;

  /**
   * The contract itself can be stored as a member of the syndicate
   **/
  struct Member {
    address receiving;
    uint256 syndicateValue;
  }
  // The first member should always be the contract itself
  Member[] public members;
  mapping (address => uint256) memberIndex;

  Payment[] public payments;

  address public decisionContract;

  constructor(address _decisionContract) public {
    decisionContract = _decisionContract;
    members.push(Member({
      receiving: address(this),
      syndicateValue: 100
    }));
  }

  /**
   * Default payment function. Adds an unsettled payment entry, or forwards the
   * payment to the updated contract (if an update proposal has passed).
   **/
  function() public payable {
    if (contractUpdated) {
      newContract.transfer(msg.value);
    } else {
      payments.push(Payment({
        sender: msg.sender,
        weiValue: msg.value,
        settled: false
      }));
    }
  }

  modifier commonDecision() {
    require(msg.sender == decisionContract);
    _;
  }

  /**
   * Make a one time payment from the syndicate
   **/
  function sendEth(address receiver, uint256 weiValue) public commonDecision {
    uint256 balance = balances[address(this)];
    require(weiValue <= balance);
    receiver.transfer(balance);
  }

  /**
   * Set values for a member
   *
   * Can only be executed by common vote
   **/
  function putMember(address _receiving, uint256 _syndicateValue) public commonDecision {
    // Before we adjust syndicate values settle any outstanding payments
    settleBalances();

    Member memory member = Member({
      receiving: _receiving,
      syndicateValue: _syndicateValue
    });
    if (isMember(_receiving)) {
      // We're updating an existing member
      totalSyndicateValue -= members[memberIndex[_receiving]].syndicateValue;
      members[memberIndex[_receiving]] = member;
      totalSyndicateValue += _syndicateValue;
    } else {
      // We're adding a new member
      members.push(member);
      totalSyndicateValue += _syndicateValue;
    }
  }

  /**
   * Determine if the supplied address has previously been added to this
   * syndicate
   **/
  function isMember(address receiving) public view returns (bool) {
    return (memberIndex[receiving] != 0 || receiving == address(this));
  }

  /**
   * Settles all outstanding payments into member balances. Should be used prior
   * to modifying value information to ensure funds are always distributed
   * using the correct value ratio at the time they were received.
   **/
  function settleBalances() public {
    for (uint256 i = lastSettledPayment; i < payments.length; i++) {
      if (payments[i].settled) continue;
      settlePayment(i);
      lastSettledPayment = i;
    }
  }

  /**
   * Settles a specific payment into smart contract balances
   **/
  function settlePayment(uint256 index) public {
    uint256 totalDistributedWei = 0;
    for (uint256 i = 0; i < members.length; i++) {
      if (members[i].syndicateValue == 0) continue;
      uint256 owedWei = payments[index].weiValue * members[i].syndicateValue / totalSyndicateValue;
      totalDistributedWei += owedWei;
      balances[members[i].receiving] += owedWei;
    }
    require(totalDistributedWei == payments[index].weiValue);
    payments[index].settled = true;
  }

  /**
   * Withdraw the balance for the calling address.
   **/
  function withdraw() public {
    if (balances[msg.sender] == 0) return;
    msg.sender.transfer(balances[msg.sender]);
    balances[msg.sender] = 0;
  }

  /**
   * Accessor for array length
   **/
  function paymentCount() public view returns (uint) {
    return payments.length;
  }

}
