// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

error MultiSigWallet__OwnersRequired();
error MultiSigWallet__InvalidApprovalNum();
error MultiSigWallet__ZeroAddress();
error MultiSigWallet__OnwerNotUnique();
error MultiSigWallet__OnlyOwner();
error MultiSigWallet__InvalidTransactionId();
error MultiSigWallet__IsApproved();
error MultiSigWallet__NotApproved();
error MultiSigWallet__IsExecuted();
error MultiSigWallet__NotEnoughApprovals();
error MultiSigWallet__TransactionFailed();

/**@title A simple Multi Sig Wallet
 * @notice This contract is for creating a simple multi signature wallet
 */
contract MultiSigWallet {
    /* TYPE DECLARATIONS */
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    /* STATE VARIABLES */
    uint256 private immutable numApproval;
    address[] private owners;
    Transaction[] private transactions;
    mapping(address => bool) private isOwner;
    mapping(uint256 => mapping(address => bool)) private approved;

    /* EVENTS */
    event Deposit(address indexed sender, uint256 indexed value);
    event Approve(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Submit(uint256 indexed txId);
    event Execute(uint256 indexed txId);

    /* MODIFIERS */
    modifier onlyOwner() {
        if (isOwner[msg.sender] == false) {
            revert MultiSigWallet__OnlyOwner();
        }
        _;
    }

    modifier validTx(uint256 txId) {
        if (txId >= transactions.length) {
            revert MultiSigWallet__InvalidTransactionId();
        }
        _;
    }

    modifier notApproved(uint256 txId) {
        if (approved[txId][msg.sender] == true) {
            revert MultiSigWallet__IsApproved();
        }
        _;
    }

    modifier notExecuted(uint256 txId) {
        if (transactions[txId].executed == true) {
            revert MultiSigWallet__IsExecuted();
        }
        _;
    }

    /* FUNCTIONS */
    /**
     * @notice The counstructor sets owners and minimal required number of approvals.
     * @param _owners: addresses array of the owners.
     * @param _numApproval: minimal number of approvals.
     * @notice number of approvals can't be greater than number of owners.
     */
    constructor(address[] memory _owners, uint256 _numApproval) {
        uint256 len = _owners.length;
        if (len < 1) {
            revert MultiSigWallet__OwnersRequired();
        }
        if (_numApproval < 1 || _numApproval > len) {
            revert MultiSigWallet__InvalidApprovalNum();
        }

        for (uint256 i; i < len; ) {
            address owner = _owners[i];
            if (owner == address(0)) {
                revert MultiSigWallet__ZeroAddress();
            }
            if (isOwner[owner] == true) {
                revert MultiSigWallet__OnwerNotUnique();
            }
            isOwner[owner] = true;
            owners.push(owner);
            unchecked {
                ++i;
            }
        }
        numApproval = _numApproval;
    }

    /**
     * @notice This function receives Eth and emits deposit event.
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    fallback() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Creates a new transaction with passed parameters.
     * @param _to: address where the transaction will be executed.
     * @param _value: value of ETH to be sent to the address.
     * @param _data: data to be sent to the address.
     */
    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        uint256 txIndex = transactions.length;
        transactions.push(
            Transaction({to: _to, value: _value, data: _data, executed: false})
        );
        emit Submit(txIndex);
    }

    /**
     * @notice This function sets the owner's approval state as approved.
     * @param txId: transaction id.
     */
    function approve(uint256 txId)
        external
        onlyOwner
        validTx(txId)
        notApproved(txId)
    {
        approved[txId][msg.sender] = true;
        emit Approve(msg.sender, txId);
    }

    /**
     * @notice This function cancels the owner's approval.
     */
    function revoke(uint256 txId)
        external
        onlyOwner
        validTx(txId)
        notExecuted(txId)
    {
        if (approved[txId][msg.sender] == false) {
            revert MultiSigWallet__NotApproved();
        }
        approved[txId][msg.sender] = false;
        emit Revoke(msg.sender, txId);
    }

    /**
     * @notice This function executes the transaction.
     * @notice The function can only be performed if there is enough approvals.
     */
    function execute(uint256 txId) external validTx(txId) notExecuted(txId) {
        if (getApprovalCount(txId) < numApproval) {
            revert MultiSigWallet__NotEnoughApprovals();
        }
        Transaction storage transaction = transactions[txId];
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        if (!success) {
            revert MultiSigWallet__TransactionFailed();
        }
        emit Execute(txId);
    }

    /* View/Pure FUNCTIONS */
    /**
     * @notice Counts the number of transaction approvals.
     * @return count The number of approvals.
     */
    function getApprovalCount(uint256 txId)
        private
        view
        returns (uint256 count)
    {
        address[] memory _owners = owners;
        uint256 len = _owners.length;
        for (uint256 i; i < len; ) {
            if (approved[txId][_owners[i]] == true) {
                count += 1;
            }
            unchecked {
                ++i;
            }
        }
    }

    function getTransaction(uint256 txId)
        external
        view
        returns (Transaction memory)
    {
        return transactions[txId];
    }

    function getNumApproval() external view returns (uint256) {
        return numApproval;
    }

    function checkIsOwner(address owner) external view returns (bool) {
        return isOwner[owner];
    }

    function checkApproved(uint256 txId, address owner)
        external
        view
        returns (bool)
    {
        return approved[txId][owner];
    }
}
