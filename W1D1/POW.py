import hashlib
import time

def pow_sha256(name,countOfZeros):
    prefix = '0' * countOfZeros
    nonce = 0
    start_time = time.time()
    
    while True:
        input_str = f"{name}{nonce}"
        hash_result = hashlib.sha256(input_str.encode()).hexdigest()
        
        if hash_result.startswith(prefix):
            end_time = time.time()
            elapsed = end_time - start_time
            return nonce, hash_result, elapsed, input_str
        
        nonce += 1

def main():
    name=input("输入昵称: ")
    print("4个0")
    nonce, hash_result, elapsed, input_str = pow_sha256(name, 4)
    print(f"input_str: {input_str}")
    print(f"Nonce: {nonce}")
    print(f"Hash: {hash_result}")
    print(f"time: {elapsed:.2f} seconds")

    print("5个0")
    nonce, hash_result, elapsed, input_str = pow_sha256(name, 5)
    print(f"input_str: {input_str}")
    print(f"Nonce: {nonce}")
    print(f"Hash: {hash_result}")
    print(f"time: {elapsed:.2f} seconds")

if __name__ == "__main__":
    main()