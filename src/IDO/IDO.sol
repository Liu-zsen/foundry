// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IDO is Ownable {

    struct Sale {
        IERC20 token;          
        uint96 tokenPrice;     
        uint96 minTarget;      //募集ETH目标
        uint96 maxCap;      //  超募ETH上限   
        uint96 totalRaised; // 已募集金额
        uint64 endTime;      
        bool claimed;          
        bool successful;       
    }
    // 状态变量 
    Sale public sale;
    mapping(address => uint96) public investments;  // 用户投资金额
    mapping(address => bool) public tokensClaimed;  // 用户是否已领取代币
    
    // 将重入保护的布尔值与其他布尔值打包
    bool private locked;

    event SaleStarted(address token, uint96 tokenPrice, uint96 minTarget, uint96 maxCap, uint64 endTime);
    event Invested(address investor, uint96 amount);
    event TokensClaimed(address investor, uint96 amount);
    event RefundClaimed(address investor, uint96 amount);
    event FundsClaimed(address owner, uint96 amount);

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor() Ownable(msg.sender) {
        locked = false;
    }
// 开始预售
    function startSale(
        address _token,
        uint96 _tokenPrice,
        uint96 _minTarget,
        uint96 _maxCap,
        uint64 _duration
    ) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        require(_tokenPrice > 0, "Invalid token price");
        require(_minTarget > 0, "Invalid min target");
        require(_maxCap >= _minTarget, "Max cap must be >= min target");
        require(_duration > 0, "Invalid duration");

        sale = Sale({
            token: IERC20(_token),
            tokenPrice: _tokenPrice,
            minTarget: _minTarget,
            maxCap: _maxCap,
            endTime: uint64(block.timestamp) + _duration,
            totalRaised: 0,
            claimed: false,
            successful: false
        });

        emit SaleStarted(_token, _tokenPrice, _minTarget, _maxCap, uint64(block.timestamp) + _duration);
    }

    function invest() external payable nonReentrant {
        require(uint64(block.timestamp) < sale.endTime, "Sale ended");
        require(msg.value > 0, "Invalid investment amount");
        require(msg.value <= type(uint96).max, "Amount too large");
        require(sale.totalRaised + uint96(msg.value) <= sale.maxCap, "Exceeds max cap");

        investments[msg.sender] += uint96(msg.value);
        sale.totalRaised += uint96(msg.value);

        emit Invested(msg.sender, uint96(msg.value));
    }

// 预售成功后用户领取代币
    function claimTokens() external nonReentrant {
        require(uint64(block.timestamp) >= sale.endTime, "Sale not ended");
        require(!tokensClaimed[msg.sender], "Already claimed");
        require(sale.totalRaised >= sale.minTarget, "Sale unsuccessful");

        sale.successful = true;
        tokensClaimed[msg.sender] = true;

        uint96 investment = investments[msg.sender];
        uint256 tokenAmount = (uint256(investment) * 1e18) / uint256(sale.tokenPrice);
        require(sale.token.transfer(msg.sender, tokenAmount), "Token transfer failed");

        emit TokensClaimed(msg.sender, investment);
    }

// 预售失败后用户领取退款
    function claimRefund() external nonReentrant {
        require(uint64(block.timestamp) >= sale.endTime, "Sale not ended");
        require(sale.totalRaised < sale.minTarget, "Sale successful");
        require(investments[msg.sender] > 0, "Nothing to refund");

        uint96 refundAmount = investments[msg.sender];
        investments[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund failed");

        emit RefundClaimed(msg.sender, refundAmount);
    }
// 预售成功后项目方提取募集资金

    function claimFunds() external onlyOwner nonReentrant {
        require(uint64(block.timestamp) >= sale.endTime, "Sale not ended");
        require(sale.totalRaised >= sale.minTarget, "Sale unsuccessful");
        require(!sale.claimed, "Funds already claimed");

        sale.claimed = true;
        (bool success, ) = payable(owner()).call{value: sale.totalRaised}("");
        require(success, "Transfer failed");

        emit FundsClaimed(owner(), sale.totalRaised);
    }
// 获取预售信息
    function getSaleInfo() external view returns (
        address token,
        uint96 tokenPrice,
        uint96 minTarget,
        uint96 maxCap,
        uint64 endTime,
        uint96 totalRaised,
        bool claimed,
        bool successful
    ) {
        return (
            address(sale.token),
            sale.tokenPrice,
            sale.minTarget,
            sale.maxCap,
            sale.endTime,
            sale.totalRaised,
            sale.claimed,
            sale.successful
        );
    }
}
