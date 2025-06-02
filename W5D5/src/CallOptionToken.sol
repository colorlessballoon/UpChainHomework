// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CallOptionToken is ERC20, Ownable {
    using SafeERC20 for IERC20;
    
    // 标的资产
    IERC20 public immutable underlyingAsset;
    
    // 计价资产
    IERC20 public immutable quoteAsset;
    
    // 行权价格（quoteAsset per underlyingAsset）
    uint256 public immutable strikePrice;
    
    // 行权截止日期
    uint256 public immutable expirationDate;
    
    // 是否已过期清算
    bool public isSettled;
    
    // 期权Token与USDT的交易对地址
    address public lpPair;
    
    event Issued(address indexed recipient, uint256 underlyingAmount, uint256 optionAmount);
    event Exercised(address indexed holder, uint256 optionAmount, uint256 underlyingAmount);
    event Settled(uint256 underlyingAmountRecovered, uint256 optionAmountBurned);
    event LPPairCreated(address indexed pairAddress);
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _underlyingAsset,
        address _quoteAsset,
        uint256 _strikePrice,
        uint256 _expirationDate
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        require(_expirationDate > block.timestamp, "Expiration must be in the future");
        underlyingAsset = IERC20(_underlyingAsset);
        quoteAsset = IERC20(_quoteAsset);
        strikePrice = _strikePrice;
        expirationDate = _expirationDate;
    }
    
    // 设置LP交易对地址（只能由owner调用一次）
    function setLPPair(address _lpPair) external onlyOwner {
        require(lpPair == address(0), "LP pair already set");
        lpPair = _lpPair;
        emit LPPairCreated(_lpPair);
    }
    
    // 项目方发行期权Token（1:1对应标的资产数量）
    function issue(address recipient, uint256 underlyingAmount) external onlyOwner {
        require(block.timestamp < expirationDate, "Option expired");
        
        // 从项目方转移标的资产到合约
        underlyingAsset.safeTransferFrom(msg.sender, address(this), underlyingAmount);
        
        // 铸造等量的期权Token
        _mint(recipient, underlyingAmount);
        
        emit Issued(recipient, underlyingAmount, underlyingAmount);
    }
    
    // 用户行权：用期权Token和报价资产兑换标的资产
    function exercise(uint256 optionAmount) external {
        require(block.timestamp <= expirationDate, "Option expired");
        require(!isSettled, "Option already settled");
        require(balanceOf(msg.sender) >= optionAmount, "Insufficient option balance");
        
        // 计算需要的报价资产数量
        uint256 quoteAmount = optionAmount * strikePrice / (10 ** decimals());
        
        // 销毁用户的期权Token
        _burn(msg.sender, optionAmount);
        
        // 从用户转移报价资产到合约
        quoteAsset.safeTransferFrom(msg.sender, address(this), quoteAmount);
        
        // 转移标的资产给用户
        underlyingAsset.safeTransfer(msg.sender, optionAmount);
        
        emit Exercised(msg.sender, optionAmount, optionAmount);
    }
    
    // 过期清算：项目方收回剩余标的资产并销毁所有未行权的期权Token
    function settle() external onlyOwner {
        require(block.timestamp > expirationDate, "Option not expired yet");
        require(!isSettled, "Already settled");
        
        isSettled = true;
        
        // 获取合约中剩余的标的资产
        uint256 underlyingBalance = underlyingAsset.balanceOf(address(this));
        
        // 销毁所有未行权的期权Token
        uint256 totalSupply = totalSupply();
        if (totalSupply > 0) {
            _burn(address(this), totalSupply); // 假设合约持有未行权的Token
        }
        
        // 将剩余标的资产转移给项目方
        if (underlyingBalance > 0) {
            underlyingAsset.safeTransfer(owner(), underlyingBalance);
        }
        
        emit Settled(underlyingBalance, totalSupply);
    }
    
    
}