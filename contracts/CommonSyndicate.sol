pragma solidity ^0.4.23;

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

  struct Payment {
    address sender;
    uint256 value;
    bool settled;
  }

  uint256 public totalValue = 0;

  /**
   * The contract itself can be stored as a member of the syndicate
   **/
  struct Member {
    address receiving;
    uint256 value;
  }
  // The first member should always be the contract itself
  Member[] public members;
  mapping (address => uint256) memberIndex;

  Payment[] public payments;

  address public commonVoting;

  constructor(address _commonVoting) public {
    commonVoting = _commonVoting;
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
        value: msg.value,
        settled: false
      }));
    }
  }

  modifier commonVote() {
    require(msg.sender == this.commonVoting);
    _;
  }

  /**
   * Set values for a member
   *
   * Can only be executed by common vote
   **/
  function putMember(address _receiving, int256 _value) public commonVote {
    Member memory member = Member({
      receiving: _receiving,
      value: _value
    });
    if (memberIndex[_receiving] == 0 && _receiving != this) {
      // We're adding a new member
      members.push(member);
      totalValue += _value;
    } else {
      // We're updating an existing member
      totalValue -= members[memberIndex[_receiving]].value;
      members[memberIndex[_receiving]] = member;
      totalValue += _value;
    }
  }

  /**
   * Settles all outstanding payments into user balances. Should be used prior
   * to modifying value information to ensure funds are always distributed
   * using the correct value ratio.
   **/
  function settleBalances() public {
    for (uint256 i = 0; i < payments.length; i++) {
      if (payments[i].settled) continue;
      settlePayment(i);
    }
  }

  /**
   * Settles a specific payment into smart contract balances.
   *
   * Funds can be withdrawn using the withdraw function below.
   **/
  function settlePayment(uint index) public {
    uint totalDistributedWei = 0;
    for (uint i = 0; i < memberAddresses.length; i++) {
      address a = memberAddresses[i];
      if (members[a].value == 0) continue;
      uint owedWei = payments[index].value * members[a].value / totalValue;
      totalDistributedWei += owedWei;
      balances[a] += owedWei;
    }
    assert(totalDistributedWei == payments[index].value);
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

  function paymentCount() public view returns (uint) {
    return payments.length;
  }

}
