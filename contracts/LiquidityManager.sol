// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IUniswapRouter.sol";

contract LiquidityManager is Initializable {
  using SafeMath for uint256;
  address public _owner;
  address public _horde;
  address public _uniswapV2Router;
  address public _uniswapV2Pair;
  address public _busd; // constant
  bool public enabledStabilizer;
  uint256 public pegPrice;
  mapping(address => bool) public _isExcluded;

  event ExcludedFromFee();
  event StabilizerEnabled();
  event Rebalanced();
  event Sell(address, uint256);
  event Buy(address, uint256);
  event PegPriceChanged(uint256);
  event HordeChanged();

  modifier onlyOwner() {
    require(_owner == msg.sender, "error: Caller is not owner!");
    _;
  }

  function initialize(address owner) public initializer {
    _uniswapV2Router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    _owner = owner;
    _busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
  }

  function setHordeToken(address horde, address pair) public onlyOwner {
    _horde = horde;
    _uniswapV2Pair = pair;
    emit HordeChanged();
  }

  function enableStabilizer(bool flag) public onlyOwner {
    enabledStabilizer = flag;
    emit StabilizerEnabled();
  }

  function setPegPrice(uint256 _p10000) public onlyOwner {
    pegPrice = _p10000;
    emit PegPriceChanged(_p10000);
  }

  function _swapHordeForBusd(uint256 hAmount) internal {
    address[] memory path = new address[](2);
    path[0] = address(_horde);
    path[1] = address(_busd);

    IERC20(_horde).approve(_uniswapV2Router, hAmount);
    IUniswapV2Router02(_uniswapV2Router)
      .swapExactTokensForTokensSupportingFeeOnTransferTokens(
        hAmount,
        0, // Accept any amount
        path,
        address(this),
        block.timestamp
      );
  }

  function _swapBusdForHorde(uint256 bAmount) internal {
    address[] memory path = new address[](2);
    path[0] = address(_busd);
    path[1] = address(_horde);

    IERC20(_busd).approve(_uniswapV2Router, bAmount);
    IUniswapV2Router02(_uniswapV2Router)
      .swapExactTokensForTokensSupportingFeeOnTransferTokens(
        bAmount,
        0, // Accept any amount
        path,
        address(this),
        block.timestamp
      );
  }

  function swapHordeToBusd(uint256 hordeAmount) external {
    require(
      IERC20(_horde).balanceOf(msg.sender) >= hordeAmount,
      "error: Not enough Horde balance!"
    );

    IERC20(_horde).transferFrom(msg.sender, address(this), hordeAmount);

    uint256 preBUSD = IERC20(_busd).balanceOf(address(this));
    _swapHordeForBusd(hordeAmount);
    uint256 newBUSD = IERC20(_busd).balanceOf(address(this)).sub(preBUSD);

    if (enabledStabilizer) {
      uint256 r1 = IERC20(_horde).balanceOf(_uniswapV2Pair);
      uint256 r2 = IERC20(_busd).balanceOf(_uniswapV2Pair);
      uint256 curPrice = r2.mul(10000).div(r1);
      uint256 priceChange;
      if (curPrice < pegPrice) {
        priceChange = pegPrice.sub(curPrice).mul(10000).div(pegPrice);
        if (priceChange > 500) {
          uint256 adjAmount = priceChange.div(2).mul(r2).div(10000);
          _swapBusdForHorde(adjAmount);
          emit Rebalanced();
        }
      }
    }
    if (_isExcluded[msg.sender]) IERC20(_busd).transfer(msg.sender, newBUSD);
    else IERC20(_busd).transfer(msg.sender, newBUSD.mul(9).div(10));
    emit Sell(msg.sender, hordeAmount);
  }

  function swapBusdToHorde(uint256 busdAmount) external {
    require(
      IERC20(_busd).balanceOf(msg.sender) >= busdAmount,
      "error: Not enough BUSD balance!"
    );

    IERC20(_busd).transferFrom(msg.sender, address(this), busdAmount);

    uint256 preHorde = IERC20(_horde).balanceOf(address(this));
    _swapBusdForHorde(busdAmount);
    uint256 newHorde = IERC20(_horde).balanceOf(address(this)).sub(preHorde);

    if (enabledStabilizer) {
      uint256 r1 = IERC20(_horde).balanceOf(_uniswapV2Pair);
      uint256 r2 = IERC20(_busd).balanceOf(_uniswapV2Pair);
      uint256 curPrice = r2.mul(10000).div(r1);
      uint256 priceChange;
      if (curPrice > pegPrice) {
        priceChange = curPrice.sub(pegPrice).mul(10000).div(pegPrice);
        if (priceChange > 500) {
          uint256 adjAmount = priceChange.div(2).mul(r1).div(10000);
          _swapHordeForBusd(adjAmount);
          emit Rebalanced();
        }
      }
    }
    IERC20(_horde).transfer(msg.sender, newHorde);
    emit Buy(msg.sender, busdAmount);
  }

  function excludeFromFee(address[] calldata adrs, bool[] calldata flags)
    external
    onlyOwner
  {
    require(adrs.length == flags.length, "error: Invalid input data");
    for (uint256 idx = 0; idx < adrs.length; idx++) {
      _isExcluded[adrs[idx]] = flags[idx];
    }
    emit ExcludedFromFee();
  }

  function withdraw(
    address token,
    uint256 amount,
    address to
  ) public onlyOwner {
    require(
      IERC20(token).balanceOf(address(this)) >= amount,
      "error: Not enough balance!"
    );
    IERC20(token).transfer(to, amount);
  }

  function addLiquidity(uint256 hAmount, uint256 bAmount) public onlyOwner {
    require(hAmount > 0 && bAmount > 0, "error: Invalid input amount!");

    IERC20(_busd).approve(_uniswapV2Router, bAmount);
    IERC20(_horde).approve(_uniswapV2Router, hAmount);

    IUniswapV2Router02(_uniswapV2Router).addLiquidity(
      _horde,
      _busd,
      hAmount,
      bAmount,
      0,
      0,
      msg.sender,
      block.timestamp
    );
  }

  function removeLiquidity(uint256 lpAmount) public onlyOwner {
    require(lpAmount > 0, "error: Invalid input amount!");
    require(
      IERC20(_uniswapV2Pair).balanceOf(msg.sender) >= lpAmount,
      "error: Not enough balance!"
    );

    IERC20(_uniswapV2Pair).transferFrom(msg.sender, address(this), lpAmount);

    IERC20(_uniswapV2Pair).approve(_uniswapV2Router, lpAmount);

    IUniswapV2Router02(_uniswapV2Router).removeLiquidity(
      _horde,
      _busd,
      lpAmount,
      0,
      0,
      msg.sender,
      block.timestamp
    );
  }
}
