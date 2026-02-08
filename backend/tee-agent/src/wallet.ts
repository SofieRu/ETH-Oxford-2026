import * as crypto from "crypto";
import * as fs from "fs";
import * as path from "path";
import { ethers, type TransactionRequest, type Provider } from "ethers";

const ALGORITHM = "aes-256-cbc";
const KEY_LEN = 32;
const IV_LEN = 16;
const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;

const DEFAULT_WALLET_FILE = "wallet.enc";
const ENV_PASSPHRASE = "WALLET_PASSPHRASE";
const ENV_WALLET_FILE = "WALLET_KEY_FILE";

/** Encrypted payload stored on disk (salt + iv + ciphertext). */
interface EncryptedPayload {
  salt: string;
  iv: string;
  data: string;
}

/**
 * Opaque wallet handle. Holds an ethers Signer internally; the private key
 * is never exported or logged.
 */
export class WalletHandle {
  readonly address: string;
  private readonly _signer: ethers.Wallet;

  constructor(signer: ethers.Wallet) {
    this._signer = signer;
    this.address = signer.address;
  }

  /** Signs a transaction and returns the signed serialized hex string. */
  async signTransaction(transaction: TransactionRequest): Promise<string> {
    return this._signer.signTransaction(transaction);
  }
}

/**
 * Derives a 32-byte key from passphrase and salt using scrypt.
 */
function deriveKey(passphrase: string, salt: Buffer): Buffer {
  return crypto.scryptSync(passphrase, salt, KEY_LEN, {
    N: SCRYPT_N,
    r: SCRYPT_R,
    p: SCRYPT_P,
  });
}

/**
 * Returns the passphrase from env. Throws if not set (avoids default secrets).
 */
function getPassphrase(): string {
  const pass = process.env[ENV_PASSPHRASE];
  if (!pass || pass.length === 0) {
    throw new Error(
      `${ENV_PASSPHRASE} must be set to encrypt/decrypt the wallet key`
    );
  }
  return pass;
}

/**
 * Returns the path to the wallet file (env or default in cwd).
 */
function getWalletPath(): string {
  const file = process.env[ENV_WALLET_FILE] ?? DEFAULT_WALLET_FILE;
  return path.isAbsolute(file) ? file : path.join(process.cwd(), file);
}

/**
 * Encrypts plaintext with AES-256-CBC using a key derived from passphrase.
 */
function encrypt(plaintext: string, passphrase: string): EncryptedPayload {
  const salt = crypto.randomBytes(16);
  const iv = crypto.randomBytes(IV_LEN);
  const key = deriveKey(passphrase, salt);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([
    cipher.update(plaintext, "utf8"),
    cipher.final(),
  ]);
  return {
    salt: salt.toString("hex"),
    iv: iv.toString("hex"),
    data: encrypted.toString("hex"),
  };
}

/**
 * Decrypts an EncryptedPayload using the passphrase.
 */
function decrypt(payload: EncryptedPayload, passphrase: string): string {
  const salt = Buffer.from(payload.salt, "hex");
  const iv = Buffer.from(payload.iv, "hex");
  const key = deriveKey(passphrase, salt);
  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  return (
    decipher.update(payload.data, "hex", "utf8") + decipher.final("utf8")
  );
}

/**
 * Creates a new Ethereum wallet using hardware-backed entropy (crypto.randomBytes),
 * encrypts the private key with AES-256-CBC, saves it to disk, and returns a
 * WalletHandle. The private key is never exported or logged.
 */
export async function generateWallet(): Promise<WalletHandle> {
  const entropy = crypto.randomBytes(32);
  const privateKeyHex = "0x" + entropy.toString("hex");
  const signer = new ethers.Wallet(privateKeyHex);
  const passphrase = getPassphrase();
  const payload = encrypt(privateKeyHex, passphrase);
  const filePath = getWalletPath();
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(payload), { mode: 0o600 });
  const handle = new WalletHandle(signer);
  console.log("[wallet] Generated new wallet:", handle.address);
  return handle;
}

/**
 * Loads an existing wallet from the encrypted storage file. Decrypts with
 * WALLET_PASSPHRASE and returns a WalletHandle. The private key is never
 * exported or logged.
 */
export function loadWallet(): WalletHandle {
  const filePath = getWalletPath();
  if (!fs.existsSync(filePath)) {
    throw new Error(`Wallet file not found: ${filePath}`);
  }
  const raw = fs.readFileSync(filePath, "utf8");
  const payload = JSON.parse(raw) as EncryptedPayload;
  const passphrase = getPassphrase();
  const privateKeyHex = decrypt(payload, passphrase);
  const signer = new ethers.Wallet(privateKeyHex);
  const handle = new WalletHandle(signer);
  console.log("[wallet] Loaded wallet:", handle.address);
  return handle;
}

/**
 * Initializes the wallet: loads from encrypted storage if it exists,
 * otherwise generates a new wallet, encrypts and saves it, then returns
 * a WalletHandle.
 */
export async function initWallet(): Promise<WalletHandle> {
  const filePath = getWalletPath();
  console.log("[wallet] initWallet: path =", filePath, "| exists =", fs.existsSync(filePath));
  if (fs.existsSync(filePath)) {
    return loadWallet();
  }
  console.log("[wallet] No existing wallet file; generating new wallet.");
  return generateWallet();
}

/**
 * Signs a transaction with the wallet and returns the signed serialized
 * transaction hex. Uses the wallet's internal signer; private key is
 * never exposed.
 */
export function signTransaction(
  wallet: WalletHandle,
  transaction: TransactionRequest
): Promise<string> {
  return wallet.signTransaction(transaction);
}

/**
 * Returns the Ethereum address of the wallet.
 */
export function getAddress(wallet: WalletHandle): string {
  return wallet.address;
}

/**
 * Fetches the wallet's native (ETH) balance from the given provider.
 */
export async function getBalance(
  wallet: WalletHandle,
  provider: Provider
): Promise<bigint> {
  return provider.getBalance(wallet.address);
}
