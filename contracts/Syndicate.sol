pragma solidity ^0.5.0;

/**
 * Syndicate
 *
 * A way to distribute ownership of ether in time
 **/

contract Syndicate {

  mapping (address => uint256) public balances;

  struct Payee {
    uint256 index;
    address payable addr;
    uint256 weiRate;
    uint256 weiPaid;
  }

  struct Payment {
    address sender;
    Payee[] payees;
    mapping (address => uint256) payeeIndexes;
    address root;
    uint256 timestamp;
    uint256 lastSettlementTimestamp;
    uint256 currentWeiRate;
    uint256 maxWeiRate;
    uint256 weiValue;
    uint256 weiPaid;
    bool isFork;
    uint256 parentIndex;
    bool isForked;
    uint256 fork1Index;
    uint256 fork2Index;
  }

  Payment[] public payments;

  event PaymentUpdated(uint256 index);
  event PaymentCreated(uint256 index);
  event BalanceUpdated(address payable target);

  /**
   * Deposit to a given address over a certain amount of time.
   **/
  function deposit(address payable _receiver, uint256 _time) external payable {
    balances[msg.sender] += msg.value;
    emit BalanceUpdated(msg.sender);
    pay(_receiver, msg.value, _time);
  }

  /**
   * Pay from sender to receiver a certain amount over a certain amount of time.
   **/
  function pay(address payable _root, uint256 _weiRate, uint256 _weiValue) public {
    // Create a payment of _weiRate wei/second for _time seconds.
    // Verify that the balance is there and value is non-zero
    require(_weiValue <= balances[msg.sender] && _weiValue > 0);
    require(_weiRate < _weiValue);
    Payee[] memory _payees;
    payments.push(Payment({
      sender: msg.sender,
      payees: _payees,
      root: _root,
      timestamp: block.timestamp,
      lastSettlementTimestamp: block.timestamp,
      currentWeiRate: 0,
      maxWeiRate: _weiRate,
      weiValue: _weiValue,
      weiPaid: 0,
      isFork: false,
      parentIndex: 0,
      isForked: false,
      fork1Index: 0,
      fork2Index: 0
    }));
    uint256 paymentIndex = payments.length - 1;
    payments[paymentIndex].payeeIndexes[_root] = 0;
    // Update the balance value of the sender to effectively lock the funds in place
    balances[msg.sender] -= _weiValue;
    emit BalanceUpdated(msg.sender);
    emit PaymentCreated(paymentIndex);
  }

  /**
   * Settle an individual payment at the current point in time.
   *
   * Can be called idempotently.
   **/
  function paymentSettle(uint256 index) public {
    assertPaymentIndexInRange(index);
    if (isPaymentSettled(index)) return;
    Payment memory payment = payments[index];
    // Guard against block timing attacks with the max operator
    uint256 elapsedTime = max(block.timestamp, payment.lastSettlementTimestamp) - payment.lastSettlementTimestamp;
    uint256 remainingWei = max(payment.weiValue, payment.weiPaid) - payment.weiPaid;
    uint256 totalWeiOwed = min(remainingWei, elapsedTime * payment.currentWeiRate);
    uint256 totalWeiPaid = 0;
    if (totalWeiOwed >= remainingWei) {
      // Split the remaining wei proportionately
      for (uint256 i = 0; i < payment.payees.length; i++) {
        uint256 weiOwed = remainingWei * payment.payees[i].weiRate / payment.currentWeiRate;
        balances[payment.payees[i].addr] += weiOwed;
        totalWeiPaid += weiOwed;
        emit BalanceUpdated(payment.payees[i].addr);
      }
      // There will be leftover value ~= remainingWei % payees.length
      // This is small enough that we can just send it to the root
      balances[payment.root] += payment.weiValue - payment.weiPaid;
      assert(isPaymentSettled(index));
    } else {
      // Pay as usual
      for (uint256 i = 0; i < payment.payees.length; i++) {
        uint256 weiOwed = payment.payees[i].weiRate * elapsedTime;
        balances[payment.payees[i].addr] += weiOwed;
        totalWeiPaid += weiOwed;
        emit BalanceUpdated(payment.payees[i].addr);
      }
      payments[index].weiPaid += totalWeiOwed;
    }
    emit PaymentUpdated(index);
  }

  /**
   * Update the weiRate for a payee in a payment.
   * Creates a new payee if necessary.
   **/
  function paymentUpdateRate(uint256 index, address payable _receiver, uint256 _newWeiRate) public {
    assertPaymentIndexInRange(index);

    Payment storage payment = payments[index];

    require(msg.sender == payment.root);


    uint256 receiverIndex = payment.payeeIndexes[_receiver];
    if (receiverIndex == 0 && _receiver != msg.sender) {
      // We need to create a new payee
      payment.payees.push(Payee({
        index: payment.payees.length,
        weiRate: 0,
        weiPaid: 0,
        addr: _receiver
      }));
      payment.payeeIndexes[_receiver] = payment.payees.length - 1;
      receiverIndex = payment.payees.length - 1;
    }

    Payee memory payee = payment.payees[receiverIndex];

    // Ensure we're below the max flow rate
    if (_newWeiRate > payee.weiRate) {
      // We're increasing the wei rate
      uint256 difference = _newWeiRate - payee.weiRate;
      require(payment.currentWeiRate + difference <= payment.maxWeiRate);
      payment.currentWeiRate += difference;
    } else if (_newWeiRate < payee.weiRate) {
      // We're decreasing the wei rate
      uint256 difference = payee.weiRate - _newWeiRate;
      require(payment.currentWeiRate - difference <= payment.maxWeiRate);
      payment.currentWeiRate -= difference;
    }
    payment.payees[receiverIndex].weiRate = _newWeiRate;
  }

  /**
   * Forks a payment to another address for the duration of a payment. Allows
   * responsibility of funds to be delegated to other addresses by payment
   * recipient.
   *
   * Payment completion time is unaffected by forking, the only thing that
   * changes is recipient(s).
   *
   * Payments can be forked until weiValue is 0, at which point the Payment is
   * settled. Child payments can also be forked.
   **/
  function paymentFork(uint256 index, address payable _receiver, uint256 _weiValue) public {
    Payment memory payment = payments[index];
    // Make sure the payment owner is operating
    require(msg.sender == payment.root);

    uint256 remainingWei = payment.weiValue - payment.weiPaid;
    uint256 remainingTime = max(0, payment.time - (block.timestamp - payment.timestamp));

    // Ensure there is enough unsettled wei in the payment
    require(remainingWei >= _weiValue);
    require(_weiValue > 0);

    // Create a new Payment of _weiValue to _receiver over the remaining time of
    // Payment at index
    payments[index].weiValue = payments[index].weiPaid;
    emit PaymentUpdated(index);

    payments.push(Payment({
      sender: msg.sender,
      receiver: _receiver,
      timestamp: block.timestamp,
      time: remainingTime,
      weiValue: _weiValue,
      weiPaid: 0,
      isFork: true,
      parentIndex: index,
      isForked: false,
      fork1Index: 0,
      fork2Index: 0
    }));
    payments[index].fork1Index = payments.length - 1;
    emit PaymentCreated(payments.length - 1);

    payments.push(Payment({
      sender: payment.receiver,
      receiver: payment.receiver,
      timestamp: block.timestamp,
      time: remainingTime,
      weiValue: remainingWei - _weiValue,
      weiPaid: 0,
      isFork: true,
      parentIndex: index,
      isForked: false,
      fork1Index: 0,
      fork2Index: 0
    }));
    payments[index].fork2Index = payments.length - 1;
    emit PaymentCreated(payments.length - 1);

    payments[index].isForked = true;
  }

  /**
   * Accessor for determining if a given payment is fully settled.
   **/
  function isPaymentSettled(uint256 index) public view returns (bool) {
    assertPaymentIndexInRange(index);
    return payments[index].weiValue == payments[index].weiPaid;
  }

  /**
   * Reverts if the supplied payment index is out of range
   **/
  function assertPaymentIndexInRange(uint256 index) public view {
    require(index < payments.length);
  }

  /**
   * Withdraw target address balance from Syndicate to ether.
   **/
  function withdraw(address payable target, uint256 weiValue) public {
    require(balances[target] >= weiValue);
    balances[target] -= weiValue;
    emit BalanceUpdated(target);
    target.transfer(weiValue);
  }

  /**
   * One argument, target address.
   **/
  function withdraw(address payable target) public {
    withdraw(target, balances[target]);
  }

  /**
   * No arguments, withdraws full balance to sender from sender balance.
   **/
  function withdraw() public {
    withdraw(msg.sender, balances[msg.sender]);
  }

  /**
   * Accessor for array length
   **/
  function paymentCount() public view returns (uint) {
    return payments.length;
  }

  /**
   * Return the smaller of two values.
   **/
  function min(uint a, uint b) private pure returns (uint) {
    return a < b ? a : b;
  }

  /**
   * Return the larger of two values.
   **/
  function max(uint a, uint b) private pure returns (uint) {
    return a > b ? a : b;
  }
}
