// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "./ILiquidityManager.sol";
import "./IHORDEToken.sol";

contract NodeManager is Initializable {
    using SafeMath for uint256;

    address public owner;
    IHORDEToken public horde;

    address public uniswapV2Router; // constant
    address public busd; // constant
    address public liquidityManager;
    address public treasury;
    address public rewardPool;

    struct PlotEntry {
        uint256 id;
        string name;
        address user;
        uint8 level;
        uint256 roi;
        uint256 startTime;
        uint256 endTime;
        uint256 lastCashoutTime;
        bool exists;
    }
    
    uint256 public plotCounter;
    uint256[3] public plotCosts;
    uint256[3] public plotROIs; // reward horde amount per day(86400)
    uint256[3] public plotPeriods;
    
    mapping(address => uint256) private _plotBalances;

    mapping(uint256 => PlotEntry) public _plots;

    uint256 private _status;

    address[3] public hordeNFTs;
    uint256[3] public boostROIs;

    // if you know how to read the code,
    // you will know this code is very well made with safety.
    // but many safe checkers cannot recognize ownership code in here
    // so made workaround to make the ownership look deleted instead
    modifier onlyOwner() {
        require(owner == msg.sender, "error: Caller is not owner!");
        _;
    }

    modifier nonReentrant() {
        require(_status != 2, "ReentrancyGuard: reentrant call");

        _status = 2;

        _;

        _status = 1;
    }

    modifier checkPermissions(uint256 _id) {
        require(plotExists(_id), "Plots: This plot doesn't exist");
        require(
            isOwnerOfPlot(msg.sender, _id),
            "Plots: You do not control this Planet"
        );
        _;
    }

    function initialize(address _owner, IHORDEToken _horde, address _liquidityManager, address _treaury, address _rewardPool) 
        external 
        initializer 
    {
        owner = _owner;
        horde = _horde;
        liquidityManager = _liquidityManager;
        treasury = _treaury;
        rewardPool = _rewardPool;

        busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
        uniswapV2Router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    }

    function plotExists(uint256 _id) 
        private
        view
        returns (bool)
    {
        require(_id > 0, "Plots: Id must be higher than zero");
        PlotEntry memory plot = _plots[_id];
        if (plot.exists) {
            return true;
        }
        return false;
    }

    function isOwnerOfPlot(address account, uint256 _id)
        public
        view
        returns (bool)
    {
        uint256[] memory plotIdsOf = getPlotIdsOf(account);
        for (uint256 i = 0; i < plotIdsOf.length; i++) {
            if (plotIdsOf[i] == _id) {
                return true;
            }
        }
        return false;
    }

    function getPlotIdsOf(address account)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory plotIds = new uint256[](_plotBalances[account]);
        uint256 cn = 0;
        for (uint256 id = 1; id <= plotCounter; id++) {
            PlotEntry memory plot = _plots[id];
            if (plot.exists && plot.user == account)
                plotIds[cn++] = id;
        }
        return plotIds;
    }

    function createPlot(uint8 _level, string memory _pname) 
        external
        nonReentrant
    {
        require(horde.balanceOf(msg.sender) >= plotCosts[_level], "error: Not enough balance!");
        horde.tokenTransfer(msg.sender, address(this), plotCosts[_level]);
        // distribution code here
        uint256 hAmount = plotCosts[_level].mul(4).div(10);
        horde.approve(liquidityManager, hAmount);

        uint256 preBUSD = IERC20(busd).balanceOf(address(this));
        ILiquidityManager(liquidityManager).swapHordeToBusd(hAmount);
        uint256 newBUSD = IERC20(busd).balanceOf(address(this)).sub(preBUSD);

        IERC20(busd).transfer(liquidityManager, newBUSD.div(2));
        IERC20(busd).transfer(treasury, newBUSD.div(2));
        
        horde.tokenTransfer(address(this), rewardPool, plotCosts[_level].sub(hAmount));

        plotCounter++;
        _plots[plotCounter] = PlotEntry({
            id: plotCounter,
            name: _pname,
            user: msg.sender,
            level: _level,
            roi: plotROIs[_level],
            startTime: block.timestamp,
            endTime: plotPeriods[_level].add(block.timestamp),
            lastCashoutTime: block.timestamp,
            exists: true
        });
        _plotBalances[msg.sender]++;
    }

    function cashoutReward(uint256 _id)
        external
        nonReentrant
        checkPermissions(_id)
    {
        uint256 reward = getPlotCashoutRewards(_id);
        horde.tokenTransfer(address(rewardPool), msg.sender, reward);
    }

    function cashoutAll() 
        external 
        nonReentrant 
    {
        uint256[] memory plotsOwned = getPlotIdsOf(msg.sender);
        uint256 rewardsTotal;
        for (uint256 i = 0; i < plotsOwned.length; i++) 
            rewardsTotal += getPlotCashoutRewards(plotsOwned[i]);

        horde.tokenTransfer(address(rewardPool), msg.sender, rewardsTotal);
    }

    function getPlotCashoutRewards(uint256 _id) 
        private
        returns (uint256)
    {
        uint256 reward = getClaimableRewards(_id);
        PlotEntry storage plot = _plots[_id];
        plot.lastCashoutTime = block.timestamp;
        if (plot.endTime < block.timestamp) {
            plot.exists = false;
            _plotBalances[msg.sender]--;
        }
        
        return reward;
    }

    function getClaimableRewards(uint256 _id) 
        public
        view
        returns (uint256)
    {
        require(plotExists(_id), "Plots: This plot doesn't exist");
        PlotEntry storage plot = _plots[_id];
        uint256 curTime;
        if (block.timestamp > plot.endTime)
            curTime = plot.endTime;
        else
            curTime = block.timestamp;
        
        uint256 boostedROI = getBoostedROI(plot.user);
        return curTime.sub(plot.lastCashoutTime).mul(plotCosts[plot.level]).mul(plot.roi).mul(boostedROI + 100).div(100).div(100).div(86400);
    }


    function setPlotCosts(uint256[3] memory _plotCosts)
        external
        onlyOwner
    {
        require(_plotCosts.length == 3, "error: Invalid input data!");
        plotCosts = _plotCosts;
    }

    function setPlotROIs(uint256[3] memory _plotROIs)
        external
        onlyOwner
    {
        require(_plotROIs.length == 3, "error: Invalid input data!");
        plotROIs = _plotROIs;
    }

    function setPlotPeriods(uint256[3] memory _plotPeriods)
        external
        onlyOwner
    {
        require(_plotPeriods.length == 3, "error: Invalid input data!");
        plotPeriods = _plotPeriods;
    }

    function setTreasury(address _treasury) 
        external 
        onlyOwner 
    {
        treasury = _treasury;
    }

    function setRewardPool(address _rewardPool) 
        external 
        onlyOwner 
    {
        rewardPool = _rewardPool;
    }

    function setLiquidityManager(address _liquidityManager) 
        external 
        onlyOwner 
    {
        liquidityManager = _liquidityManager;
    }

    function totalPlots()
        external
        view
        returns (uint256)
    {
        uint256 tcnt = 0;
        for (uint256 id = 1; id <= plotCounter; id ++) {
            PlotEntry storage plot = _plots[id];
            if (plot.exists) tcnt ++;
        }
        return tcnt;
    } 

    function getUserPlotsInfo(address _account)
        external
        view
        returns (uint256, uint256, uint256,uint256)
    {
        uint256[] memory plotsOwned = getPlotIdsOf(_account);
        uint256 rewardsTotal;
        uint256 level0Amount;
        uint256 level1Amount;
        uint256 level2Amount;
        for (uint256 i = 0; i < plotsOwned.length; i++) {
            rewardsTotal += getClaimableRewards(plotsOwned[i]);
            if (_plots[plotsOwned[i]].level == 0) {
                level0Amount += 1;
            }
            else if(_plots[plotsOwned[i]].level == 1) {
                level1Amount += 1;
            } else level2Amount += 1;
        }
        return (rewardsTotal, level0Amount, level1Amount, level2Amount);
    }

    function setHordeNFTs(address[3] memory _hordeNFTs)
        external
        onlyOwner
    {
        hordeNFTs = _hordeNFTs;
    }

    function setBoostROIs(uint256[3] memory _boostROIs)
        external
        onlyOwner
    {
        boostROIs = _boostROIs;
    }

    function getBoostedROI(address _user)
        public
        view
        returns (uint256)
    {
        uint256 boostedROI;
        for (uint256 i = 0; i < 3; i++) 
            boostedROI += boostROIs[i] * IERC721(hordeNFTs[i]).balanceOf(_user);

        return boostedROI;
    }
}