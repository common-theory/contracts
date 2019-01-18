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
  }

  struct Payment {
    address sender;
    Payee[] payees;
    mapping (address => uint256) payeeIndexes;
    address root;
    uint256 timestamp;
    uint256 time;
    uint256 weiRate;
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
  function pay(address payable _receiver, uint256 _weiRate, uint256 _time) public {
    // Create a payment of _weiRate wei/second for _time seconds.
    // Verify that the balance is there and value is non-zero
    uint256 weiValue = _weiRate * _time;
    require(weiValue <= balances[msg.sender] && weiValue > 0);
    // Verify the time is non-zero
    require(_time > 0);
    Payee[] memory _payees;
    payments.push(Payment({
      sender: msg.sender,
      payees: _payees,
      root: _receiver,
      timestamp: block.timestamp,
      time: _time,
      weiRate: _weiRate,
      weiPaid: 0,
      isFork: false,
      parentIndex: 0,
      isForked: false,
      fork1Index: 0,
      fork2Index: 0
    }));
    uint256 paymentIndex = payments.length - 1;
    payments[paymentIndex].payeeIndexes[_receiver];
    // Update the balance value of the sender to effectively lock the funds in place
    balances[msg.sender] -= weiValue;
    emit BalanceUpdated(msg.sender);
    emit PaymentCreated(paymentIndex);
  }

  /**
   * Settle an individual payment at the current point in time.
   *
   * Can be called idempotently.
   **/
  function paymentSettle(uint256 index) public {
    uint256 owedWei = paymentWeiOwed(index);
    balances[payments[index].receiver] += owedWei;
    emit BalanceUpdated(payments[index].receiver);
    payments[index].weiPaid += owedWei;
    emit PaymentUpdated(index);
  }

  /**
   * Return the wei owed on a payment at the current block timestamp.
   **/
  function paymentWeiOwed(uint256 index) public view returns (uint256) {
    assertPaymentIndexInRange(index);
    Payment memory payment = payments[index];
    // Calculate owed wei based on current time and total wei owed/paid
    return max(payment.weiPaid, payment.weiValue * min(block.timestamp - payment.timestamp, payment.time) / payment.time) - payment.weiPaid;
  }

  /**
   * Transfer ownership of value in a payment to another receiving address.
   * Creates a new payee if necessary.
   **/
  function paymentTransferValue(uint256 index, uint256 _weiValue, address payable _receiver) public {
    assertPaymentIndexInRange(index);
    Payment memory payment = payments[index];
    uint256 receiverIndex = payment.payeeIndexes[_receiver];
    uint256 senderIndex = payment.payeeIndexes[msg.sender];

    require(senderIndex != 0 || msg.sender == payment.root);
    Payee memory sender = payment.payees[senderIndex];
    // Ensure the sender is the message sender and exists
    require(sender.addr == msg.sender);

    // Ensure we've got the funds to do this
    require(sender.weiValue >= _weiValue);

    if (receiverIndex != 0 || msg.sender == _receiver) {
      // The payee already exists, just modify the values
      payment.payees[receiverIndex].weiValue += _weiValue;
    } else {
      // We need to create a new payee
      payment.payees.push(Payee({
        index: payment.payees.length,
        weiValue: _weiValue,
        addr: _receiver
      }));
    }
    payment.payees[senderIndex].weiValue -= _weiValue;
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
