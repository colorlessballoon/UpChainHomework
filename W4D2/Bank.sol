// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title Bank
 * @dev 使用可迭代链表存储存款余额前十名的银行合约
 */
contract Bank {
    // 存储每个用户的余额
    mapping(address => uint256) public balances;
    
    // 链表结构，存储存款排名
    mapping(address => address) private _nextDepositor;
    // 记录链表中的用户数量
    uint256 public listSize;
    // 链表头部的哨兵节点地址
    address constant GUARD = address(1);
    // 最大存储的排名数量
    uint256 constant MAX_RANK = 10;
    
    address public immutable owner;
    
    constructor() {
        owner = msg.sender;
        _nextDepositor[GUARD] = GUARD;
    }

    function withDraw(uint256 amount) public {
        require(msg.sender == owner, "Only the owner can withdraw");
        require(amount <= address(this).balance, "Insufficient balance in the contract");
        payable(owner).transfer(amount);
    }
    
    function deposit() public payable {
        require(msg.value > 0, "Transfer amount must be greater than 0");
        balances[msg.sender] += msg.value;
        updateRanking(msg.sender);
    }

    /**
     * @dev 更新用户的存款排名
     * @param depositor 存款用户地址
     */
    function updateRanking(address depositor) internal {
        // 如果用户已经在链表中，先移除
        if (_nextDepositor[depositor] != address(0)) {
            removeDepositor(depositor);
        }
        
        // 找到合适的插入位置
        address current = GUARD;
        address next = _nextDepositor[GUARD];
        
        // 遍历链表找到合适的插入位置
        while (next != GUARD && balances[next] >= balances[depositor]) {
            current = next;
            next = _nextDepositor[next];
        }
        
        // 如果链表未满或新用户余额大于最后一个用户，则插入
        if (listSize < MAX_RANK || balances[depositor] > balances[_getLastDepositor()]) {
            _nextDepositor[depositor] = next;
            _nextDepositor[current] = depositor;
            listSize++;
            
            // 如果超出最大排名，移除最后一个
            if (listSize > MAX_RANK) {
                address last = _getLastDepositor();
                removeDepositor(last);
            }
        }
    }

    /**
     * @dev 从链表中移除用户
     * @param depositor 要移除的用户地址
     */
    function removeDepositor(address depositor) internal {
        address current = GUARD;
        address next = _nextDepositor[GUARD];
        
        // 找到要移除的用户的前一个节点
        while (next != depositor && next != GUARD) {
            current = next;
            next = _nextDepositor[next];
        }
        
        if (next == depositor) {
            _nextDepositor[current] = _nextDepositor[depositor];
            _nextDepositor[depositor] = address(0);
            listSize--;
        }
    }

    /**
     * @dev 获取链表中最后一个用户
     * @return 最后一个用户的地址
     */
    function _getLastDepositor() internal view returns (address) {
        address current = GUARD;
        while (_nextDepositor[current] != GUARD) {
            current = _nextDepositor[current];
        }
        return current;
    }

    /**
     * @dev 获取存款排名前N的用户
     * @param n 要获取的排名数量
     * @return 包含前N名用户地址的数组
     */
    function getTopDepositors(uint256 n) public view returns (address[] memory) {
        require(n <= MAX_RANK && n <= listSize, "Invalid rank number");
        address[] memory depositors = new address[](n);
        address current = _nextDepositor[GUARD];
        
        for (uint256 i = 0; i < n; i++) {
            depositors[i] = current;
            current = _nextDepositor[current];
        }
        
        return depositors;
    }

    receive() external payable {
        deposit();
    }
}