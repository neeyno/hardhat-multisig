// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title Multi Signature Wallet
 * @notice This contract is for creating off-chain signature-based multi sig wallet.
 */
contract MultiSigWallet2 {
    using ECDSA for bytes32;

    /* ERRORS */
    error MultiSig__OnlyOwners();
    error MultiSig__SignatureNotInOrder();
    error MultiSig__NotEnoughSignatures();
    error MultiSig__TransactionFailed();

    /**
     * STATE VARIABLES
     */
    mapping(address => bool) private _isOwner;
    //address[] private owners;
    uint256 private _numSignatures;
    uint256 private _nonce;
    uint256 private constant CHAIN_ID = 31337;

    /**
     * EVENTS
     */
    event Deposited(address indexed sender, uint256 indexed value);
    //event Approve(address indexed owner, uint256 indexed txId);
    //event Revoke(address indexed owner, uint256 indexed txId);
    //event Submit(uint256 indexed txId);
    event Executed(
        address indexed sender,
        uint256 indexed nonce,
        address to,
        uint256 value,
        bytes data,
        bytes result
    );

    /**
     * MODIFIERS
     */
    modifier onlyOwner() {
        if (_isOwner[msg.sender] == false) {
            revert MultiSig__OnlyOwners();
        }
        _;
    }

    /* FUNCTIONS */
    /**
     * @notice The counstructor sets owners and minimal required number of approvals.
     * @param owners: addresses array of the owners.
     * @param numSignatures: minimal number of signatures.
     * @notice number of approvals can't be greater than number of owners.
     */
    constructor(address[] memory owners, uint256 numSignatures) {
        require(owners.length > 1, "Owners required");
        require(numSignatures > 1, "Signatures required");

        for (uint256 i; i < owners.length; ) {
            address owner = owners[i];
            require(owner != address(0), "Owner is zero address");
            _isOwner[owner] = true;
            unchecked {
                ++i;
            }
        }
        _numSignatures = numSignatures;
        //_chainId = chainId;
    }

    /**
     * @notice This function receives Eth and emits deposit event.
     */
    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    fallback() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Creates a new transaction with passed parameters.
     * @param hashedData: data to be sent to the address.
     */
    // function submitTx(bytes32 hashedData) external onlyOwner {
    //     uint256 txIndex = transactionCount;
    //     transactionCount = txIndex + 1;
    //     transactions[txIndex] = hashedData;
    //     emit Submit(txIndex);
    // }

    /**
     * @notice This function sets the owner's approval state as approved.
     * @param txId: transaction id.
     */
    // function approve(uint256 txId) external onlyOwner validTx(txId) {
    //     if (approved[txId][msg.sender] == true) {
    //         revert MultiSig_IsApproved();
    //     }
    //     approved[txId][msg.sender] = true;
    //     emit Approve(msg.sender, txId);
    // }

    /**
     * @notice This function cancels the owner's approval.
     */
    // function revoke(uint256 txId) external onlyOwner validTx(txId) {
    //     if (approved[txId][msg.sender] == false) {
    //         revert MultiSig_NotApproved();
    //     }
    //     approved[txId][msg.sender] = false;
    //     emit Revoke(msg.sender, txId);
    // }

    /**
     * @notice This function executes the transaction.
     * @notice The function can only be performed if there is enough approvals.
     */
    function executeTransaction(
        bytes[] memory signatures,
        bytes memory data
    ) external {
        if (!_checkOwner(msg.sender)) {
            revert MultiSig__OnlyOwners();
        }
        uint256 nonce = _nonce;
        bytes32 hash = getHash(CHAIN_ID, nonce, data);
        uint256 numValidSig;
        address previous;
        for (uint256 i; i < signatures.length; ) {
            address signer = recoverSigner(hash, signatures[i]);
            if (signer < previous) {
                revert MultiSig__SignatureNotInOrder();
            }
            unchecked {
                if (_checkOwner(signer)) numValidSig++;
                ++i;
            }
        }
        if (numValidSig < _numSignatures)
            revert MultiSig__NotEnoughSignatures();

        (address payable to, uint256 txValue, bytes memory txData) = abi.decode(
            data,
            (address, uint256, bytes)
        );
        (bool success, bytes memory result) = to.call{value: txValue}(txData);
        if (!success) revert MultiSig__TransactionFailed();
        _nonce = nonce++;
        emit Executed(msg.sender, nonce, to, txValue, txData, result);
    }

    function _checkOwner(address account) private view returns (bool) {
        return _isOwner[account];
    }

    /* Getter FUNCTIONS */
    /**
     * @notice -
     * @return  Recovered signer address.
     */
    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) public pure returns (address) {
        bytes32 ethSignedMsg = hash.toEthSignedMessageHash(); //toEthSignedMessageHash(hash);
        // keccak256(
        //     abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        // );
        return ethSignedMsg.recover(signature);
    }

    function getHash(
        uint256 chainId,
        uint256 nonce,
        bytes memory data
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), chainId, nonce, data));
    }

    function getNumSigRequired() public view returns (uint256) {
        return _numSignatures;
    }

    function getNonce() public view returns (uint256) {
        return _nonce;
    }

    function isOwner(address account) public view returns (bool) {
        return _checkOwner(account);
    }
}
