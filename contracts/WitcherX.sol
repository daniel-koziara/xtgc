// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Ownable.sol";
import "./ERC20.sol";
import "./SafeMath.sol";
import "./IUniswap.sol";

interface IStaking {
    function updatePool(uint256 amount) external;
}

contract WitcherX is Ownable, ERC20 {
    using SafeMath for uint256;

    mapping(address => uint256) public rOwned;
    mapping(address => uint256) public tOwned;
    mapping(address => uint256) public totalSend;
    mapping(address => uint256) public totalReceived;
    mapping(address => uint256) public lockedAmount;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedFromReward;
    mapping(address => bool) public isAutomatedMarketMakerPairs;
    mapping(address => bool) public isHolder;

    address[] private _excluded;

    address public burnWallet;
    address public TreasureAddress;
    IStaking public stakingContract;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 333333333333 * (10 ** 18);
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    uint256 public TreasureFeeTotal;
    uint256 public holders;

    uint256[] public TreasureFee;
    uint256[] public reflectionFee;
    uint256[] public stakingFee;
    uint256[] public burnFee;


    uint256 private _treasureFee;
    uint256 private _reflectionFee;
    uint256 private _stakingFee;
    uint256 private _burnFee;

    IUniswapRouter public uniswapRouter;
    address public uniswapPair;

    address public titanxAddress;



    event LockToken(uint256 amount, address user);
    event UnLockToken(uint256 amount, address user);
    event SwapTokensAmountUpdated(uint256 amount);

    constructor(address owner, address _titanxAddress) ERC20("WitcherX", "WITCHERX") {
        titanxAddress = _titanxAddress;

        rOwned[owner] = _rTotal;

        uniswapRouter = IUniswapRouter(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        ); // uniswap router02 v2
        uniswapPair = IUniswapFactory(uniswapRouter.factory()).createPair(
            address(this),
            titanxAddress
        );

        burnWallet = address(0x0000000000000000000000000000000000000369);

        isExcludedFromFee[owner] = true;
        isExcludedFromFee[address(this)] = true;


        TreasureFee.push(200);
        TreasureFee.push(200);
        TreasureFee.push(200);

        reflectionFee.push(100);
        reflectionFee.push(100);
        reflectionFee.push(100);

        stakingFee.push(100);
        stakingFee.push(100);
        stakingFee.push(100);

        burnFee.push(50);
        burnFee.push(50);
        burnFee.push(50);


        _excludeFromReward(address(burnWallet));
        _excludeFromReward(address(uniswapPair));
        _excludeFromReward(address(this));
        _setAutomatedMarketMakerPair(uniswapPair, true);

        isHolder[owner] = true;
        holders += 1;

        totalReceived[owner] += _tTotal;
        emit Transfer(address(0), owner, _tTotal);
    }

    receive() external payable {}

    function excludeFromLimit(address account, bool status) external onlyOwner {
        isExcludedFromFee[address(account)] = status;
    }

    function updateAutomatedMarketMakerPair(
        address pair,
        bool value
    ) external onlyOwner {
        require(pair != address(0), "Zero address");
        _setAutomatedMarketMakerPair(pair, value);
        if (value) {
            _excludeFromReward(address(pair));
        } else {
            _includeInReward(address(pair));
        }
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (isExcludedFromReward[account]) return tOwned[account];
        return tokenFromReflection(rOwned[account]);
    }

    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function _excludeFromReward(address account) internal {
        if (rOwned[account] > 0) {
            tOwned[account] = tokenFromReflection(rOwned[account]);
        }
        isExcludedFromReward[account] = true;
        _excluded.push(account);
    }

    function _includeInReward(address account) internal {
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                tOwned[account] = 0;
                isExcludedFromReward[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            isAutomatedMarketMakerPairs[pair] != value,
            "Automated market maker pair is already set to that value"
        );
        isAutomatedMarketMakerPairs[pair] = value;
    }

    function setStakingContract(IStaking contractAddress) external onlyOwner {
        require(address(contractAddress) != address(0), "Zero address");
        require(
            address(stakingContract) == address(0),
            "Staking contract already set"
        );

        stakingContract = IStaking(contractAddress);

        _excludeFromReward(address(stakingContract));
        isExcludedFromFee[address(stakingContract)] = true;
    }

    function setTreasureAddress(address wallet) external onlyOwner {
        require(address(wallet) != address(0), "Zero address");
        require(address(TreasureAddress) == address(0), "Treasure contract already set");

        TreasureAddress = wallet;

        _excludeFromReward(address(TreasureAddress));
        isExcludedFromFee[address(TreasureAddress)] = true;
    }

    function lockToken(uint256 amount, address user) external {
        require(msg.sender == address(stakingContract), "sender not allowed");

        uint256 unlockBalance = balanceOf(user) - lockedAmount[user];
        require(unlockBalance >= amount, "locking amount exceeds balance");
        lockedAmount[user] += amount;
        emit LockToken(amount, user);
    }

    function unlockToken(uint256 amount, address user) external {
        require(msg.sender == address(stakingContract), "sender not allowed");
        require(lockedAmount[user] >= amount, "amount is not correct");

        lockedAmount[user] -= amount;
        emit UnLockToken(amount, user);
    }

    function unlockSend(uint256 amount, address user) external {
        require(msg.sender == address(stakingContract), "sender not allowed");
        require(lockedAmount[user] >= amount, "amount is not correct");

        lockedAmount[user] -= amount;
        IERC20(address(this)).transferFrom(
            address(user),
            address(stakingContract),
            amount
        );
        emit UnLockToken(amount, user);
    }

    function airdropToken(uint256 amount) external {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            balanceOf(msg.sender) - lockedAmount[msg.sender] >= amount,
            "transfer amount exceeds balance"
        );

        _tokenTransfer(msg.sender, address(this), amount, true, true);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(
        uint256 tAmount
    )
        private
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tTreasure
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tTreasure,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tTreasure
        );
    }

    function _getTValues(
        uint256 tAmount
    ) private view returns (uint256, uint256, uint256) {
        uint256 tFee = calculateReflectionFee(tAmount);
        uint256 tTreasure = calculateTreasureFee(tAmount);

        uint256 tTransferAmount = tAmount.sub(tFee).sub(tTreasure);
        return (tTransferAmount, tFee,  tTreasure);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tTreasure,
        uint256 currentRate
    ) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTreasure = tTreasure.mul(currentRate);

        uint256 rTransferAmount = rAmount.sub(rFee).sub(rTreasure);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                rOwned[_excluded[i]] > rSupply || tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(rOwned[_excluded[i]]);
            tSupply = tSupply.sub(tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }


    function _takeTreasure(uint256 tTreasure) private {
        uint256 currentRate = _getRate();
        uint256 rTreasure = tTreasure.mul(currentRate);
        rOwned[address(this)] = rOwned[address(this)].add(rTreasure);
        if (isExcludedFromReward[address(this)])
            tOwned[address(this)] = tOwned[address(this)].add(tTreasure);
    }

    function _takeStaking(uint256 tStaking) private {
        uint256 currentRate = _getRate();
        uint256 rStaking = tStaking.mul(currentRate);
        rOwned[address(stakingContract)] = rOwned[address(stakingContract)].add(
            rStaking
        );
        if (isExcludedFromReward[address(stakingContract)])
            tOwned[address(stakingContract)] = tOwned[address(stakingContract)]
                .add(tStaking);
    }

    function _takeBurn(uint256 tBurn) private {
        uint256 currentRate = _getRate();
        uint256 rBurn = tBurn.mul(currentRate);
        rOwned[burnWallet] = rOwned[burnWallet].add(rBurn);
        if (isExcludedFromReward[burnWallet])
            tOwned[burnWallet] = tOwned[burnWallet].add(tBurn);
    }

    function calculateReflectionFee(
        uint256 _amount
    ) private view returns (uint256) {
        return _amount.mul(_reflectionFee).div(10000);
    }

    function calculateTreasureFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_treasureFee).div(10000);
    }

    function calculateStakingFee(
        uint256 _amount
    ) private view returns (uint256) {
        return _amount.mul(_stakingFee).div(10000);
    }


    function calculateBurnFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_burnFee).div(10000);
    }

    function removeAllFee() private {
        _reflectionFee = 0;
        _stakingFee = 0;
        _treasureFee = 0;
        _burnFee = 0;
    }

    function applyBuyFee() private {
        _reflectionFee = reflectionFee[0];
        _stakingFee = stakingFee[0];
        _treasureFee = TreasureFee[0];
        _burnFee = burnFee[0];
    }

    function applySellFee() private {
        _reflectionFee = reflectionFee[1];
        _stakingFee = stakingFee[1];
        _treasureFee = TreasureFee[1];
        _burnFee = burnFee[1];
    }

    function applyP2PFee() private {
        _reflectionFee = reflectionFee[2];
        _stakingFee = stakingFee[2];
        _treasureFee = TreasureFee[2];
        _burnFee = burnFee[2];
    }

    function applyAirdropFee() private {
        _reflectionFee = 10000;
        _stakingFee = 0;
        _treasureFee = 0;
        _burnFee = 0;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            balanceOf(from) - lockedAmount[from] >= amount,
            "transfer amount exceeds balance"
        );

        if (!isHolder[address(to)]) {
            isHolder[to] = true;
            holders += 1;
        }

        if ((balanceOf(from) - amount) == 0) {
            isHolder[from] = false;
            holders -= 1;
        }



        bool takeFee = true;
        if (isExcludedFromFee[from] || isExcludedFromFee[to]) {
            takeFee = false;
        } else {
            if (!isHolder[address(this)]) {
                isHolder[address(this)] = true;
                holders += 1;
            }

            if (!isHolder[address(stakingContract)]) {
                isHolder[address(stakingContract)] = true;
                holders += 1;
            }

            if (!isHolder[address(burnWallet)]) {
                isHolder[address(burnWallet)] = true;
                holders += 1;
            }
        }

        uint256 treasureFeeAmount = calculateTreasureFee(amount);
        if (takeFee && treasureFeeAmount > 0) {
            amount = amount.sub(treasureFeeAmount);
            super._transfer(from, TreasureAddress, treasureFeeAmount);
            TreasureFeeTotal += treasureFeeAmount;
        }
        _tokenTransfer(from, to, amount, takeFee, false);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee,
        bool airdrop
    ) private {
        totalSend[sender] += amount;

        if (!takeFee) {
            removeAllFee();
        } else if (airdrop) {
            applyAirdropFee();
        } else if (
            !isAutomatedMarketMakerPairs[sender] &&
            !isAutomatedMarketMakerPairs[recipient]
        ) {
            applyP2PFee();
        } else if (isAutomatedMarketMakerPairs[recipient]) {
            applySellFee();
        } else {
            applyBuyFee();
        }

        uint256 _totalFee = _reflectionFee +
            _stakingFee +
            _treasureFee +
            _burnFee;
        if (_totalFee > 0) {
            uint256 _feeAmount = amount.mul(_totalFee).div(10000);
            totalReceived[recipient] += amount.sub(_feeAmount);
        } else {
            totalReceived[recipient] += amount;
        }

        uint256 tBurn = calculateBurnFee(amount);
        if (tBurn > 0) {
            _takeBurn(tBurn);
            emit Transfer(sender, address(burnWallet), tBurn);
        }

        uint256 tTreasure = calculateTreasureFee(amount);
        if (tTreasure > 0) {
            _takeTreasure(tTreasure);

            emit Transfer(sender, address(TreasureAddress), tTreasure);
        }

        uint256 tStaking = calculateStakingFee(amount);
        if (tStaking > 0) {
            _takeStaking(tStaking);
            stakingContract.updatePool(tStaking);
            emit Transfer(sender, address(stakingContract), tStaking);
        }

        if (isExcludedFromReward[sender] && !isExcludedFromReward[recipient]) {
            _transferFromExcluded(sender, recipient, amount, tStaking, tBurn);
        } else if (
            !isExcludedFromReward[sender] && isExcludedFromReward[recipient]
        ) {
            _transferToExcluded(sender, recipient, amount, tStaking, tBurn);
        } else if (
            !isExcludedFromReward[sender] && !isExcludedFromReward[recipient]
        ) {
            _transferStandard(sender, recipient, amount, tStaking, tBurn);
        } else if (
            isExcludedFromReward[sender] && isExcludedFromReward[recipient]
        ) {
            _transferBothExcluded(sender, recipient, amount, tStaking, tBurn);
        } else {
            _transferStandard(sender, recipient, amount, tStaking, tBurn);
        }
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 tStaking,
        uint256 tBurn
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tTreasure
        ) = _getValues(tAmount);

        tTransferAmount = tTransferAmount.sub(tStaking).sub(tBurn);
        rTransferAmount = rTransferAmount.sub(tStaking.mul(_getRate())).sub(
            tBurn.mul(_getRate())
        );

        rOwned[sender] = rOwned[sender].sub(rAmount);
        rOwned[recipient] = rOwned[recipient].add(rTransferAmount);

        _takeTreasure(tTreasure);
        _reflectFee(rFee, tFee);

        TreasureFeeTotal += tTreasure;

        if (tTreasure > 0) {
            emit Transfer(sender, address(this), tTreasure);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 tStaking,
        uint256 tBurn
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tTreasure
        ) = _getValues(tAmount);

        tTransferAmount = tTransferAmount.sub(tStaking).sub(tBurn);
        rTransferAmount = rTransferAmount.sub(tStaking.mul(_getRate())).sub(
            tBurn.mul(_getRate())
        );

        rOwned[sender] = rOwned[sender].sub(rAmount);
        tOwned[recipient] = tOwned[recipient].add(tTransferAmount);
        rOwned[recipient] = rOwned[recipient].add(rTransferAmount);

        _takeTreasure(tTreasure);
        _reflectFee(rFee, tFee);


        TreasureFeeTotal += tTreasure;

        if (tTreasure > 0) {
            emit Transfer(sender, address(this), tTreasure);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 tStaking,
        uint256 tBurn
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tTreasure
        ) = _getValues(tAmount);

        tTransferAmount = tTransferAmount.sub(tStaking).sub(tBurn);
        rTransferAmount = rTransferAmount.sub(tStaking.mul(_getRate())).sub(
            tBurn.mul(_getRate())
        );

        tOwned[sender] = tOwned[sender].sub(tAmount);
        rOwned[sender] = rOwned[sender].sub(rAmount);
        rOwned[recipient] = rOwned[recipient].add(rTransferAmount);

        _takeTreasure(tTreasure);
        _reflectFee(rFee, tFee);

        TreasureFeeTotal += tTreasure;

        if (tTreasure > 0) {
            emit Transfer(sender, address(this), tTreasure);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 tStaking,
        uint256 tBurn
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tTreasure
        ) = _getValues(tAmount);

        tTransferAmount = tTransferAmount.sub(tStaking).sub(tBurn);
        rTransferAmount = rTransferAmount.sub(tStaking.mul(_getRate())).sub(
            tBurn.mul(_getRate())
        );

        tOwned[sender] = tOwned[sender].sub(tAmount);
        rOwned[sender] = rOwned[sender].sub(rAmount);
        tOwned[recipient] = tOwned[recipient].add(tTransferAmount);
        rOwned[recipient] = rOwned[recipient].add(rTransferAmount);


        _takeTreasure(tTreasure);
        _reflectFee(rFee, tFee);

        TreasureFeeTotal += tTreasure;

        if (tTreasure > 0) {
            emit Transfer(sender, address(this), tTreasure);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function swapTitanXForXTGC(uint256 titanxAmount) private {

        address titanxTokenAddress = titanxAddress;
        address xTGCTokenAddress = address(this);

        address[] memory path = new address[](2);
        path[0] = titanxTokenAddress;
        path[1] = xTGCTokenAddress;

        IERC20(titanxTokenAddress).approve(address(uniswapRouter), titanxAmount);

        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            titanxAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 titanxAmount) public onlyOwner {
        IERC20(address(this)).approve(address(uniswapRouter), tokenAmount);
        IERC20(titanxAddress).approve(address(uniswapRouter), titanxAmount);

        uniswapRouter.addLiquidity(
            titanxAddress,
            address(this),
            titanxAmount,
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }
}