import hashlib
import time
from Crypto.PublicKey import RSA
from Crypto.Signature import pkcs1_15
from Crypto.Hash import SHA256
from Crypto import Random

def pow_sha256(name,countOfZeros):
    prefix = '0' * countOfZeros
    nonce = 0
    while True:
        input_str = f"{name}{nonce}"
        hash_result = hashlib.sha256(input_str.encode()).hexdigest()
        if hash_result.startswith(prefix):
            return hash_result
        nonce += 1

def generate_rsa_keypair():
    random_generator = Random.new().read
    key = RSA.generate(2048, random_generator)
    private_key = key.export_key()
    public_key = key.publickey().export_key()
    return private_key, public_key

def sign_message(private_key, message):
    key = RSA.import_key(private_key)
    h = SHA256.new(message.encode())
    signature = pkcs1_15.new(key).sign(h)
    return signature

def verify_signature(public_key, message, signature):
    try:
        key = RSA.import_key(public_key)
        h = SHA256.new(message.encode())
        pkcs1_15.new(key).verify(h, signature)
        return True
    except (ValueError, TypeError):
        return False
    
def main():
    private_key, public_key=generate_rsa_keypair()
    print("私钥为:",private_key.decode())
    print("公钥为:",public_key.decode())
    name=input("输入昵称: ")
    hash=pow_sha256(name,4)
    print("哈希值为:",hash)
    signature=sign_message(private_key, hash)
    verify_signature_result = verify_signature(public_key, hash, signature)
    if verify_signature_result:
        print("签名验证成功")
    else:
        print("签名验证失败")
    verify_signature_result = verify_signature(public_key, "fakeHash", signature)
    if verify_signature_result:
        print("签名验证成功")
    else:
        print("签名验证失败")

if __name__ == "__main__":
    main()

    