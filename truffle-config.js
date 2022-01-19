const HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "region laugh shrug grape expand van aware master tiny during thank loyal";

module.exports = {
  networks: {
    develop: {
      host: "127.0.0.1",
      port: 9545,
      network_id: "*", // Match any network id
      provider: function() {
        // return new HDWalletProvider(mnemonic, "ws://127.0.0.1:9545/", 0 , 50);
        return new HDWalletProvider({
          mnemonic: mnemonic, 
          providerOrUrl: "ws://127.0.0.1:9545/",
          numberOfAddresses: 50,
          gasPrice: 100000000000,
          gas: 6721975 // gas limit
        })
      }
    },
    development: {
      host: "127.0.0.1",
      port: 9545,
      network_id: "*", // Match any network id
      provider: function() {
        // return new HDWalletProvider(mnemonic, "ws://127.0.0.1:9545/", 0 , 50);
        return new HDWalletProvider({
          mnemonic: mnemonic, 
          providerOrUrl: "ws://127.0.0.1:9545/",
          numberOfAddresses: 50,
          gasPrice: 100000000000,
          gas: 6721975 // gas limit
        })
      }
    },
    GanacheGUI: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ethereum port (default: none)
      network_id: "5777",       // Any network (default: none)
      gasPrice: 100000000000,
      gas: 6721975 // gas limit
    },
  },
  compilers: {
    solc: {
      version: "^0.8.0"
    }
  }
};