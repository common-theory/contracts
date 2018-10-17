const PrivateKeyProvider = require('truffle-privatekey-provider');

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*'
    },
    rinkeby: {
      provider: new PrivateKeyProvider(process.env.RINKEBY_PRIVATE_KEY, 'http://commontheory.io:4545');
      network_id: '4'
    },
    live: {
      host: 'eth.commontheory.io',
      port: 80,
      network_id: 1
    }
  }
};
