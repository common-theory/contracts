const Syndicate = artifacts.require('Syndicate');
const assert = require('assert');
const BN = require('bn.js');

/**
 * Syndicate contract tests
 **/
contract('Syndicate', accounts => {

  /**
   * Tests deposit(address payable _receiver, uint256 _time) with a zero _time
   * argument.
   *
   * - Send Ether to Syndicate via deposit()
   * - Verify same transaction payment settlement
   **/
  it('should instant deposit', async () => {
    const _contract = await Syndicate.deployed();
    // Get a reference to a normal web3.eth.Contract, not a TruffleContract
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 100;
    const time = 0;
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const balance = await contract.methods.balances(owner).call();
    assert.equal(weiValue.toString(), balance.toString());
  });

  /**
   * Tests deposit(address payable _receiver, uint256 _time) with non-zero _time
   * argument.
   *
   * - Send Ether to Syndicate via deposit()
   * - Verify payment settlement every network block rate (or 1 second) until
   *   30 seconds after payment settlement.
   **/
  it('should deposit over time', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 2491;
    const time = process.env.CI ? 150 : 30;
    // Time past the payment completion time to test
    const overrunTime = 30;
    // Flush the Syndicate balance from the owner address
    await contract.methods.withdraw().send({
      from: owner,
      gas: 300000
    });
    // Deposit from owner address
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    const payment = await contract.methods.payments(paymentIndex).call();

    // Check payment values over time
    while (true) {
      // Wait 1 second between loop iterations
      await new Promise(r => setTimeout(r, 1000));
      // Settle the Payment at the current point in time
      await contract.methods.paymentSettle(paymentIndex).send({
        from: owner,
        gas: 300000
      });
      const _payment = await contract.methods.payments(paymentIndex).call();
      const now = Math.floor(new Date() / 1000);
      const totalWeiOwed = +payment.weiValue * Math.min(now - +payment.timestamp, +payment.time) / +payment.time;
      // Ensure that weiPaid is less than the logically calculated owed wei at
      // the loop timestamp (which should always be >= block.timestamp)
      assert.ok(+_payment.weiPaid <= totalWeiOwed);

      if (now > +payment.timestamp + +payment.time + overrunTime) break;
    }

    const balance = await contract.methods.balances(owner).call();
    // Ensure balance is equal to payment.weiValue
    assert.equal(balance, weiValue);
    // Verify that isPaymentSettled() is operating sanely
    assert.ok(await contract.methods.isPaymentSettled(paymentIndex));
  });

  /**
   * Tests deposit via fallback function, should function same as deposit() with
   * a zero _time value.
   *
   * - Send Ether to Syndicate contract
   * - Verify same transaction payment settlement
   **/
  it('fallback should fail', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[1];
    const weiValue = 100;
    // Flush the Syndicate balance from the owner address
    await contract.methods.withdraw().send({
      from: owner,
      gas: 300000
    });
    await assert.rejects(web3.eth.sendTransaction({
      from: owner,
      to: _contract.address,
      value: weiValue
    }));
  });

  /**
   * Ensures that 0 value payments fail.
   **/
  it('should fail to pay with no value', async () => {
    const _contract = await Syndicate.deployed();
    // Get a reference to a normal web3.eth.Contract, not a TruffleContract
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 100;
    const time = 0;
    // Flush the Syndicate balance from the owner address
    await contract.methods.withdraw().send({
      from: owner,
      gas: 300000
    });
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    await assert.rejects(contract.methods.pay(accounts[1], 0, 0).send({
      from: owner,
      gas: 300000
    }), '0 value payment should fail');
  });

  /**
   * Tests withdraw() function with no arguments.
   *
   * - Deposit using Syndicate.deposit()
   * - Withdraw balance
   * - Verify network Ether balance
   **/
  it('should withdraw balance with no args', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = new BN('500');
    const time = 0;
    const gasPrice = new BN(web3.eth.gasPrice);
    await contract.methods.withdraw().send({
      from: owner
    });
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000,
      gasPrice
    });
    const ownerWei = new BN(await web3.eth.getBalance(owner));
    const receipt = await contract.methods.withdraw().send({
      from: owner,
      gas: 300000,
      gasPrice
    });
    const balance = await contract.methods.balances(owner).call();
    assert.equal(0, +balance);

    const withdrawalGasUsed = new BN(receipt.cumulativeGasUsed);
    const withdrawalWeiCost = withdrawalGasUsed.mul(gasPrice);

    const expectedWei = ownerWei.add(weiValue).sub(withdrawalWeiCost);

    const newOwnerWei = new BN(await web3.eth.getBalance(owner));

    // Verify the current owner address value against the value before the
    // withdrawal - withdrawal cost + payment.weiValue
    assert.ok(expectedWei.eq(newOwnerWei));
  });

  /**
   * Tests withdraw(address target) function.
   **/
  it('should withdraw balance with target address arg', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = new BN('5000');
    const time = 0;
    await contract.methods.withdraw().send({
      from: owner
    });
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const ownerWei = new BN(await web3.eth.getBalance(owner));
    const receipt = await contract.methods.withdraw(owner).send({
      from: accounts[4],
      gas: 300000
    });

    const expectedWei = ownerWei.add(weiValue);
    const newOwnerWei = new BN(await web3.eth.getBalance(owner));
    // Verify the current owner address value against the value before the
    // withdrawal - withdrawal cost + payment.weiValue
    assert.ok(expectedWei.eq(newOwnerWei));
  });

  /**
   * Tests withdraw(address target, uint256 weiValue) function.
   **/
  it('should withdraw balance with target address and weiValue args', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = new BN('5000');
    const withdrawalWeiValue = new BN('500');
    const targetAddress = web3.eth.accounts.create().address;
    await contract.methods.deposit(targetAddress, 0).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    await contract.methods.withdraw(targetAddress, withdrawalWeiValue.toString()).send({
      from: owner,
      gas: 300000,
    });
    const targetAddressWei = new BN(await web3.eth.getBalance(targetAddress));
    assert.ok(withdrawalWeiValue.eq(targetAddressWei));
  });

  /**
   * Tests withdraw(address target, uint256 weiValue, uint256[] memory indexesToSettle) function.
   **/
  it('should withdraw balance and settle payment', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = new BN('5000');
    const withdrawalWeiValue = weiValue.div(new BN(2));
    const time = 60;
    const targetAddress = web3.eth.accounts.create().address;
    await contract.methods.deposit(targetAddress, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentCount = await contract.methods.paymentCount().call();
    const paymentIndex = +paymentCount - 1;
    // Wait for half the payment time period
    await new Promise(r => setTimeout(r, 10 + time * 1000 / 2));
    await contract.methods.withdraw(targetAddress, withdrawalWeiValue.toString(), [paymentIndex]).send({
      from: owner,
      gas: 300000
    });
    const targetAddressWei = new BN(await web3.eth.getBalance(targetAddress));
    assert.ok(targetAddressWei.gte(withdrawalWeiValue));
  });

  /**
   * Tests assertPaymentIndexInRange(uint256 paymentIndex) function.
   **/
  it('assertPaymentIndexInRange should fail for out of range index', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    await assert.rejects(
      contract.methods.assertPaymentIndexInRange(-1).call(),
      'Method should throw for negative value'
    );
    const paymentCount = await contract.methods.paymentCount().call();
    await assert.rejects(
      contract.methods.assertPaymentIndexInRange(+paymentCount).call(),
      'Method should throw for value longer than paymentCount'
    );
  });

  /**
   * Run a payment over time and test isPaymentSettled over time.
   **/
  it('isPaymentSettled should evaluate correctly', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    await contract.methods.withdraw().send({
      from: owner
    });
    const time = 60;
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: 100,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    assert.equal(false, await contract.methods.isPaymentSettled(paymentIndex).call());
    await new Promise(r => setTimeout(r, time * 1000 / 4));
    await contract.methods.paymentSettle(paymentIndex).send({
      from: owner,
      gas: 300000
    });
    assert.equal(false, await contract.methods.isPaymentSettled(paymentIndex).call());
    await new Promise(r => setTimeout(r, time * 1000));
    await contract.methods.paymentSettle(paymentIndex).send({
      from: owner,
      gas: 300000
    });
    assert.equal(true, await contract.methods.isPaymentSettled(paymentIndex).call());
  });

  /**
   * Payment should fail for value larger than balance
   **/
  it('should fail to make payment larger than balance', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const balance = await contract.methods.balances(owner).call();
    await assert.rejects(
      contract.methods.pay(accounts[3], +balance + 1, 0).send({
        from: owner,
        gas: 300000
      }),
      'Pay function should fail for weiValue > balance'
    );
  });
});
