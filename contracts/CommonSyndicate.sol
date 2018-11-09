pragma solidity ^0.4.23;

/**
 * The CommonSyndicate contract
 *
 * A way for distributed groups of people to work together and come to consensus
 * on use of funds.
 **/

/**
 * Things it would be cool to be able to do:
 *   - Vote to move syndicate money into DAI
 *   - Use bancor liquidity to diversify holding upon vote
 **/

contract CommonSyndicate {

  mapping (address => uint) public balances;

  bool public contractUpdated = false;
  address public newContract;

  struct Payment {
    address sender;
    uint value;
    bool settled;
  }

  Payment[] public payments;

  address public decisionContract;

  constructor(address _decisionContract) public {
    decisionContract = _decisionContract;
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

  /**
   * Settles all outstanding payments into user balances. Should be used prior
   * to modifying value information to ensure funds are always distributed
   * using the correct value ratio.
   **/
  function settleBalances() public {
    for (uint i = 0; i < payments.length; i++) {
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
