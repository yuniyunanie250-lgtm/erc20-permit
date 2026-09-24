// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ERC-20 with EIP-2612 permit.
/// @notice Approvals signed off-chain and submitted by a third party, so a user
///         never needs an approval transaction before a swap or a deposit.
contract ERC20Permit {
    error PermitExpired(uint256 deadline, uint256 now_);
    error InvalidSignature();
    error InsufficientBalance(uint256 available, uint256 needed);
    error InsufficientAllowance(uint256 available, uint256 needed);
    error InvalidRecipient();

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    /// @dev keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 public constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    /// @dev keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    bytes32 public immutable DOMAIN_SEPARATOR;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name_)), keccak256(bytes("1")), block.chainid, address(this))
        );
    }

    function mint(address to, uint256 amount) external {
        if (to == address(0)) revert InvalidRecipient();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spend(from, msg.sender, amount);
        _move(from, to, amount);
        return true;
    }

    /// @notice Set an allowance from an EIP-712 signature instead of a transaction.
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (block.timestamp > deadline) revert PermitExpired(deadline, block.timestamp);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        if (ecrecover(digest, v, r, s) != owner) revert InvalidSignature();
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _move(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert InvalidRecipient();
        if (balanceOf[from] < amount) revert InsufficientBalance(balanceOf[from], amount);
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _spend(address owner, address spender, uint256 amount) internal {
        uint256 allowed = allowance[owner][spender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance(allowed, amount);
            allowance[owner][spender] = allowed - amount;
        }
    }
}
