require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-ethers")
require("dotenv").config()
require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("hardhat-gas-reporter")
//require("solidity-coverage")
//require("hardhat-contract-sizer")

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const GOERLI_RPC_URL =
    process.env.ALCHEMY_GOERLI_URL || "https://eth-goerli/example..."
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x141..."
// optional
//const MNEMONIC = process.env.MNEMONIC

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "other key"
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "other key"

module.exports = {
    solidity: "0.8.13",
    defaultNetwork: "hardhat",
    networks: {
        goerli: {
            url: GOERLI_RPC_URL,
            accounts: [PRIVATE_KEY],
            chainId: 5,
            blockConfirmations: 6,
        },
        hardhat: {
            chainId: 31337,
            blockConfirmations: 1,
        },
        localhost: {
            url: "http://127.0.0.1:8545/",
            chainId: 31337,
            blockConfirmations: 1,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
        owner1: {
            default: 1,
        },
        owner2: {
            default: 2,
        },
    },
    etherscan: {
        // yarn hardhat verify --network <NETWORK> <CONTRACT_ADDRESS> <CONSTRUCTOR_PARAMETERS>
        apiKey: {
            goerli: ETHERSCAN_API_KEY,
        },
    },
    gasReporter: {
        enabled: true,
        outputFile: "gas-report.txt",
        noColors: true,
        currency: "USD",
        //coinmarketcap: COINMARKETCAP_API_KEY,
    },
    mocha: {
        timeout: 300000, // 1000 = 1sec
    },
}
