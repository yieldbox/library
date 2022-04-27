// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/JoeRouter.sol";

contract LavaToken is ERC20, Ownable, Pausable {
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) private blacklisted;
    mapping(address => bool) public whitelistedTax;
    mapping(address => bool) public lpPairs;

    address public usdce;
    address public lpRouter;
    address public rewardPool;
    address public treasury;
    address public lavaFinance;

    uint256 public transferTax; // 4 decimals. 1000 = 0.1 = 10%
    uint256 public salesTax; // 4 decimals. 1000 = 0.1 = 10%
    uint256 public nodeSalesTax; // 4 decimals. 1000 = 0.1 = 10%

    uint256 public maxPerWallet;

    uint256 public liquidityCooldown;
    bool private antiBotEnabled;
    uint256 public caughtBotsCount;
    uint256 private additionalLiquidityCooldown;

    constructor(
        uint256 _liquidityCooldown,
        uint256 _additionalLiquidityCooldown
    ) ERC20("LavaToken", "LAVA") {
        uint256 supply = 10_000_000e18;
        whitelisted[msg.sender] = true;
        whitelistedTax[msg.sender] = true;
        whitelisted[address(this)] = true;
        whitelistedTax[address(this)] = true;
        _mint(msg.sender, supply);
        maxPerWallet = 20_000e18;
        liquidityCooldown = block.number + _liquidityCooldown;
        additionalLiquidityCooldown = _additionalLiquidityCooldown;
    }

    function setAntiBotEnabled(bool _antiBotEnabled) external onlyOwner {
        antiBotEnabled = _antiBotEnabled;
    }

    function setWhitelistMultiple(address[] memory users, bool status)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < users.length; i++) {
            whitelisted[users[i]] = status;
        }
    }

    function setBlacklistMultiple(address[] memory users, bool status)
        external
        onlyOwner
    {
        uint256 blockNum = status ? block.number - 1 : 0;
        for (uint256 i = 0; i < users.length; i++) {
            blacklisted[users[i]] = blockNum;
        }
    }

    function setWhitelistTaxMultiple(address[] memory users, bool status)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < users.length; i++) {
            whitelistedTax[users[i]] = status;
        }
    }

    function setTaxCollectors(address _rewardPool, address _treasury)
        external
        onlyOwner
    {
        if (_rewardPool != address(0)) {
            rewardPool = _rewardPool;
            whitelisted[rewardPool] = true;
            whitelistedTax[rewardPool] = true;
        }
        if (_treasury != address(0)) {
            treasury = _treasury;
            whitelisted[treasury] = true;
            whitelistedTax[treasury] = true;
        }
    }

    function setLavaFinance(address _lavaFinance) external onlyOwner {
        require(_lavaFinance != address(0));
        lavaFinance = _lavaFinance;
    }

    function setUsdceAndRouter(address _usdce, address _lpRouter)
        external
        onlyOwner
    {
        require(_usdce != address(0), "Cannot be 0");
        require(_lpRouter != address(0), "Cannot be 0");
        usdce = _usdce;
        lpRouter = _lpRouter;
    }

    function setLpPair(address _lpPair, bool _status) external onlyOwner {
        require(_lpPair != address(0), "Cannot be 0");
        lpPairs[_lpPair] = _status;
        whitelisted[_lpPair] = _status;
    }

    function setTaxes(
        uint256 _transferTax,
        uint256 _salesTax,
        uint256 _nodeSalesTax
    ) external onlyOwner {
        require(_salesTax <= 2500, "Cannot be more than 25%");
        require(_transferTax <= 5000, "Cannot be more than 50%");
        require(_nodeSalesTax <= 2000, "Cannot be more than 20%");
        transferTax = _transferTax;
        salesTax = _salesTax;
        nodeSalesTax = _nodeSalesTax;
    }

    function setMaxPerWallet(uint256 _maxPerWallet) external onlyOwner {
        require(_maxPerWallet >= 1000, "Cannot less then 1000");
        maxPerWallet = _maxPerWallet;
    }

    function setLiquidityControl(uint256 _cooldownBlocks) external onlyOwner {
        require(_cooldownBlocks <= 500, "Cannot be more than 500");
        liquidityCooldown = block.number + _cooldownBlocks;
    }

    function withdrawFromBlacklisted(address wallet) public onlyOwner {
        require(isBlacklisted(wallet), "Not blacklisted");
        uint256 amount = balanceOf(wallet);
        blacklisted[wallet] = 0;
        _transfer(wallet, rewardPool, amount);
        blacklisted[wallet] = block.number - 1;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function isBlacklisted(address user) public view returns (bool) {
        return (blacklisted[user] > 0 && blacklisted[user] != block.number);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(!isBlacklisted(from), "Not allowed");
        require(!paused() || (whitelisted[from] && whitelisted[to]), "Paused");
        if (!whitelisted[to]) {
            require(
                balanceOf(to) + amount <= maxPerWallet,
                "Max wallet amount reached"
            );
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferFrom(from, to, amount);
        return true;
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        address owner = _msgSender();
        _transferFrom(owner, to, amount);
        return true;
    }

    function _transferFrom(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (
            (block.number < liquidityCooldown + additionalLiquidityCooldown ||
                (antiBotEnabled && tx.origin != to)) &&
            blacklisted[to] == 0 &&
            !whitelisted[to]
        ) {
            blacklisted[to] = block.number;
            caughtBotsCount++;
        }
        if (lpPairs[from] || lpPairs[to]) {
            if (lpPairs[to] && !whitelistedTax[from] && from != address(this)) {
                // Sales Tax
                uint256 totalSalesTax = salesTax;
                if (nodeSalesTax > 0) {
                    totalSalesTax +=
                        nodeSalesTax *
                        IERC721(lavaFinance).balanceOf(from);
                    if (totalSalesTax > 5000) {
                        totalSalesTax = 5000;
                    }
                }
                uint256 feeAmount = (amount * totalSalesTax) / 1e4;
                amount -= feeAmount;
                if (feeAmount > 0) {
                    _transfer(from, address(this), feeAmount);
                    swapLavaForTokens(feeAmount);
                }
            }
        } else if (!whitelistedTax[from] && !whitelistedTax[to]) {
            uint256 feeAmount = (amount * transferTax) / 1e4;
            amount -= feeAmount;
            if (feeAmount > 0) {
                _transfer(from, rewardPool, feeAmount);
                // add to reward pool
            }
        }

        _transfer(from, to, amount);
    }

    function swapLavaForTokens(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = usdce;
        _approve(address(this), lpRouter, tokenAmount);
        JoeRouter(lpRouter)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tokenAmount,
                0, // accept any amount of tokens
                path,
                treasury,
                block.timestamp + 10
            );
    }
}
