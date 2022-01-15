const HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 9545,
      network_id: "*", // Match any network id
      provider: function() {
        return new HDWalletProvider(mnemonic, "ws://127.0.0.1:9545/");
      }
    },
    GanacheGUI: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ethereum port (default: none)
      network_id: "5777",       // Any network (default: none)
    },
  },
  compilers: {
    solc: {
      version: "^0.8.0"
    }
  }
};