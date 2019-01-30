const Delegate = artifacts.require('Delegate');
const assert = require('assert');
const BN = require('bn.js');

const DEFAULT_GAS = 300000;

/**
 * Delegate contract tests
 *
 * accounts[0] is the initial delegate
 **/
contract('Delegate', accounts => {

  /**
   * Tests the fallback payment function
   **/
  it('should accept payment', async () => {
    const _contract = await Delegate.deployed();
    // Get a reference to a normal web3.eth.Contract, not a TruffleContract
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[1];
    const weiValue = 100;
    await web3.eth.sendTransaction({
      from: owner,
      to: _contract.address,
      value: weiValue
    });
  });

  /**
   * Tests payment creation from Delegate contract
   **/
  it('should create payment', async () => {
    const _contract = await Delegate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const weiValue = 500;
    await web3.eth.sendTransaction({
      from: accounts[1],
      to: _contract.address,
      value: weiValue
    });
    await contract.methods.paymentCreate(weiValue, accounts[2], 100).send({
      from: accounts[0],
      gas: DEFAULT_GAS
    });
  });

  /**
   * Ensures failure from non-delegate
   **/
  it('should fail to create payment from non-delegate', async () => {
    const _contract = await Delegate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const weiValue = 500;
    await web3.eth.sendTransaction({
      from: accounts[1],
      to: _contract.address,
      value: weiValue
    });
    await assert.rejects(contract.methods.paymentCreate(weiValue, accounts[2], 100).send({
      from: accounts[1],
      gas: DEFAULT_GAS
    }));
  });

});
