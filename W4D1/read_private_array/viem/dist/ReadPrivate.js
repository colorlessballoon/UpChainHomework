"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const viem_1 = require("viem");
const chains_1 = require("viem/chains");
async function readPrivateArray() {
    // 创建客户端
    const client = (0, viem_1.createPublicClient)({
        chain: chains_1.foundry,
        transport: (0, viem_1.http)('http://127.0.0.1:8545')
    });
    // 这里需要替换为实际的合约地址
    const contractAddress = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';
    try {
        // 1. 首先获取数组长度
        // 数组长度存储在 slot 0
        const lengthSlot = '0x0000000000000000000000000000000000000000000000000000000000000000';
        const lengthHex = await client.getStorageAt({
            address: contractAddress,
            slot: lengthSlot
        });
        if (!lengthHex) {
            console.error('无法获取数组长度');
            return;
        }
        const length = Number(lengthHex);
        console.log(`数组长度: ${length}`);
        // 2. 计算数组起始位置的 slot
        // 对于动态数组，实际数据从 keccak256(slot) 开始
        const arraySlot = '0x0000000000000000000000000000000000000000000000000000000000000000';
        const startSlot = BigInt('0x' + (0, viem_1.keccak256)(arraySlot).slice(2));
        console.log(`数组起始位置: ${startSlot.toString(16)}`);
        console.log('--------------------------------');
        console.log('读取数组数据:');
        // 3. 读取每个结构体
        for (let i = 0; i < length; i++) {
            // 每个结构体占用 2 个 slot
            // slot 0: address user (20 bytes) + uint64 startTime (8 bytes)
            // slot 1: uint256 amount
            const baseSlot = startSlot + BigInt(i * 2);
            const baseSlotHex = '0x' + baseSlot.toString(16).padStart(64, '0');
            const slot0Data = await client.getStorageAt({
                address: contractAddress,
                slot: baseSlotHex
            });
            const nextSlotHex = '0x' + (baseSlot + 1n).toString(16).padStart(64, '0');
            const slot1Data = await client.getStorageAt({
                address: contractAddress,
                slot: nextSlotHex
            });
            if (!slot0Data || !slot1Data) {
                console.log(`无法获取索引 ${i} 的数据`);
                continue;
            }
            // 解析数据
            if (slot0Data.length >= 66) {
                // 从 slot0 末尾获取 address (20 bytes)
                const addressEnd = slot0Data.length;
                const addressStart = addressEnd - 40; // 每个地址是 20 字节 = 40 个十六进制字符
                const addressHex = slot0Data.slice(addressStart);
                const user = '0x' + addressHex;
                // 从 slot0 中间获取 startTime (8 bytes)
                // startTime 位于 address 之前
                const timeStart = addressStart - 16; // 时间戳是 8 字节 = 16 个十六进制字符
                const timeHex = slot0Data.slice(timeStart, addressStart);
                const startTime = timeHex ? BigInt('0x' + timeHex) : 0n;
                // slot1 是一个完整的 uint256 (amount)
                const amount = slot1Data && slot1Data !== '0x' ? BigInt(slot1Data) : 0n;
                // 使用用户要求的格式输出
                console.log(`locks[${i}]: user:${user}, startTime:${startTime}, amount:${amount}`);
            }
            else {
                console.log(`locks[${i}]: 数据格式错误`);
            }
        }
    }
    catch (error) {
        console.error('读取数组时发生错误:', error);
    }
}
// 运行函数
readPrivateArray().catch(console.error);
