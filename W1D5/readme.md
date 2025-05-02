## 使用流程

1. 首先部署ERC20合约
2. 部署tokenBank合约，填入ERC20合约地址
3. 在ERC20合约中approve tokenBank合约使用调用者的token数量
4. 调用tokenBank的deposit将调用者的token存入Bank账户
5. 使用tokenBank合约部署者地址调用withDraw函数，将token转入管理员账户