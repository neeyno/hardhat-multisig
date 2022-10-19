const { assert, expect } = require("chai")
const { network, ethers, getNamedAccounts, deployments } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("MultiSig Wallet unit test", async () => {
          let multiSig, owners, deployer, owner1, owner2, accounts
          const numApprovals = "2"

          beforeEach(async function () {
              accounts = await ethers.getSigners()
              owners = accounts.slice(0, 3)
              ;[deployer, owner1, owner2] = owners
              await deployments.fixture(["multisig"])
              multiSig = await ethers.getContract("MultiSigWallet")
          })

          describe("Constructor", function () {
              it("sets the number of approvals", async function () {
                  const actualApprovalsNum = await multiSig.getNumApproval()
                  assert.equal(actualApprovalsNum.toString(), numApprovals)
              })

              it("sets the owners", async function () {
                  for (let i = 0; i < owners.length; i++) {
                      const multiSigConnected = multiSig.connect(
                          owners[i].address
                      )
                      const isOwner = await multiSigConnected.checkIsOwner(
                          owners[i].address
                      )
                      assert.isTrue(isOwner)
                  }
              })
          })

          describe("Receives eth", function () {
              const testValue = ethers.utils.parseEther("1")

              it("trigers receive function", async function () {
                  const testTx = {
                      gasPrice: 20000000000,
                      gasLimit: 1000000,
                      from: owner1.address,
                      to: multiSig.address,
                      value: testValue,
                      nonce: ethers.provider.getTransactionCount(
                          owner1.address,
                          "latest"
                      ),
                  }

                  await new Promise(async (resolve, reject) => {
                      multiSig.once("Deposit", async (sender, value, event) => {
                          // event listener for Deposit
                          try {
                              assert.equal(sender, owner1.address)
                              assert.equal(
                                  value.toString(),
                                  testValue.toString()
                              )
                              assert.equal(event.event, "Deposit")
                              resolve() // if try passes, resolves the promise
                          } catch (e) {
                              reject(e) // if try fails, rejects the promise
                          }
                      })
                      const txResponse = await owner1.sendTransaction(testTx)
                      const txReceipt = await txResponse.wait(1)
                  })
              })

              it("trigers fallback function", async function () {
                  const tx = {
                      gasPrice: 20000000000,
                      gasLimit: 1000000,
                      from: owner2.address,
                      to: multiSig.address,
                      value: testValue,
                      nonce: ethers.provider.getTransactionCount(
                          owner1.address,
                          "latest"
                      ),
                      data: ethers.utils.hexlify(
                          ethers.utils.toUtf8Bytes("<fallback>")
                      ),
                  }

                  await new Promise(async (resolve, reject) => {
                      multiSig.once("Deposit", async (sender, value, event) => {
                          // event listener for Deposit
                          try {
                              assert.equal(sender, owner2.address)
                              assert.equal(
                                  value.toString(),
                                  testValue.toString()
                              )
                              assert.equal(event.event, "Deposit")
                              resolve() // if try passes, resolves the promise
                          } catch (e) {
                              reject(e) // if try fails, rejects the promise
                          }
                      })
                      const txResponse = await owner2.sendTransaction(tx)
                      const txReceipt = await txResponse.wait(1)
                  })
              })
          })

          let _tx
          beforeEach(function () {
              _tx = {
                  to: owners[2].address,
                  value: ethers.utils.parseEther("0.1"),
                  data: ethers.utils.hexlify(
                      ethers.utils.toUtf8Bytes("some data")
                  ),
              }
          })

          describe("Submit transaction", function () {
              it("creates a new transaction", async function () {
                  const submitTxRes = await multiSig
                      .connect(deployer)
                      .submit(_tx.to, _tx.value, _tx.data)
                  const submitReceipt = await submitTxRes.wait(1)
                  const { txId } = submitReceipt.events[0].args
                  const transaction = await multiSig.getTransaction(
                      txId.toString()
                  )

                  assert.equal(txId.toString(), "0")
                  assert.equal(
                      transaction.value.toString(),
                      _tx.value.toString()
                  )
                  assert.equal(transaction.data, _tx.data)
                  assert.equal(transaction.executed, false)
              })
          })

          describe("Approve transaction", function () {
              beforeEach(async function () {
                  const submitTxRes = await multiSig
                      .connect(deployer)
                      .submit(_tx.to, _tx.value, _tx.data)
                  await submitTxRes.wait(1)
              })

              it("should approve", async function () {
                  const approveTx = await multiSig
                      .connect(deployer)
                      .approve("0")

                  const txReceipt = await approveTx.wait(1)
                  const { owner: msgSender, txId } = txReceipt.events[0].args
                  const isApproved = await multiSig.checkApproved(
                      "0",
                      deployer.address
                  )

                  assert.equal(isApproved, true)
                  assert.equal(msgSender, deployer.address)
                  assert.equal(txId.toString(), "0")
              })
          })

          describe("Revoke transaction", function () {
              beforeEach(async function () {
                  const submitTxRes = await multiSig
                      .connect(deployer)
                      .submit(_tx.to, _tx.value, _tx.data)
                  await submitTxRes.wait(1)
                  const approveTx = await multiSig
                      .connect(deployer)
                      .approve("0")

                  await approveTx.wait(1)
              })

              it("should revoke approval", async function () {
                  const revokeTx = await multiSig.connect(deployer).revoke("0")
                  const txReceipt = await revokeTx.wait(1)
                  const { owner: msgSender, txId } = txReceipt.events[0].args
                  const isApproved = await multiSig.checkApproved(
                      "0",
                      deployer.address
                  )

                  assert.equal(isApproved, false)
                  assert.equal(msgSender, deployer.address)
                  assert.equal(txId.toString(), "0")
              })
          })

          describe("execute transaction", function () {
              beforeEach(async function () {
                  const depositTx = await deployer.sendTransaction({
                      gasPrice: 20000000000,
                      gasLimit: 1000000,
                      from: deployer.address,
                      to: multiSig.address,
                      value: ethers.utils.parseEther("0.1"),
                      nonce: ethers.provider.getTransactionCount(
                          deployer.address,
                          "latest"
                      ),
                  })
                  await depositTx.wait(1)
                  const submitTxRes = await multiSig
                      .connect(deployer)
                      .submit(_tx.to, _tx.value, _tx.data)
                  await submitTxRes.wait(1)
              })

              it("reverts execution with insufficient approvals", async function () {
                  const approveTx = await multiSig
                      .connect(deployer)
                      .approve("0")
                  await approveTx.wait(1)

                  await expect(
                      multiSig.connect(deployer).execute("0")
                  ).to.be.revertedWith("MultiSigWallet__NotEnoughApprovals()")
              })

              it("should execute with sufficient approvals", async function () {
                  for (let i = 0; i < owners.length; i++) {
                      const approveTx = await multiSig
                          .connect(owners[i])
                          .approve("0")
                      await approveTx.wait(1)
                  }
                  const toBalanceBefore = await multiSig.provider.getBalance(
                      _tx.to
                  )
                  const executeTx = await multiSig
                      .connect(deployer)
                      .execute("0")
                  const txReceipt = await executeTx.wait(1)
                  const { txId } = txReceipt.events[0].args
                  ///const { gasUsed, effectiveGasPrice } = txReceipt
                  const toBalanceAfter = await multiSig.provider.getBalance(
                      _tx.to
                  )
                  const transaction = await multiSig.getTransaction(
                      txId.toString()
                  )

                  assert.equal(txId, "0")
                  assert.equal(
                      toBalanceAfter.sub(toBalanceBefore).toString(),
                      transaction.value.toString()
                  )
                  assert.equal(transaction.executed, true)
              })
          })
      })
