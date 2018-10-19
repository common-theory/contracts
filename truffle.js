const PrivateKeyProvider = require('truffle-privatekey-provider');

const rinkebyKey = process.env.RINKEBY_PRIVATE_KEY || 'd82433dae4571119702a0b5d9eddf4695e01914b92eb7a13c7c23b044f54a1e2';

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*'
    },
    rinkeby: {
      provider: new PrivateKeyProvider(rinkebyKey, 'https://rinkeby.commontheory.io'),
      network_id: '4'
    },
    live: {
      host: 'eth.commontheory.io',
      port: 80,
      network_id: 1
    }
  }
};
