const { getNamedAccounts, deployments, network, ethers } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config.js")
const { verify } = require("../utils/verify.js")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer, owner1, owner2 } = await getNamedAccounts()

    const owners = [deployer, owner1, owner2]
    const numApprovals = "2"
    const mswArgs = [owners, numApprovals]

    const miltiSigWallet = await deploy("MultiSigWallet", {
        contract: "MultiSigWallet",
        from: deployer,
        args: mswArgs,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY
    ) {
        log("Verifying...")
        await verify(miltiSigWallet.address, mswArgs)
    }

    log("------------------------------------------")
}

module.exports.tags = ["all", "multisig"]
