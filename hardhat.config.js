require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      forking: {
        url: "https://mainnet.infura.io/v3/a99dac21da204fa3b9aa35245be1ef23",
      }
    },
    localnode: {
      url: "http://127.0.0.1:8545",
    }
  }
};
