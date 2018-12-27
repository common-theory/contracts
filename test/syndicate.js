const Syndicate = artifacts.require('CommonSyndicate');
const assert = require('assert');

contract('Syndicate', accounts => {

  it('should initialize', async (...args) => {
    console.log(args);
    const contract = await Syndicate.deployed();
    assert.equal(true, true);
  });

});
