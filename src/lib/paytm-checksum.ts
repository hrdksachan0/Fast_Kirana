import crypto from 'crypto';

export class PaytmChecksum {
  private static iv = "@@@@&&&&####$$$$";

  static encrypt(input: string, key: string): string {
    const cipher = crypto.createCipheriv('aes-128-cbc', Buffer.from(key), Buffer.from(PaytmChecksum.iv));
    let encrypted = cipher.update(input, 'utf8', 'base64');
    encrypted += cipher.final('base64');
    return encrypted;
  }

  static decrypt(encrypted: string, key: string): string {
    const decipher = crypto.createDecipheriv('aes-128-cbc', Buffer.from(key), Buffer.from(PaytmChecksum.iv));
    let decrypted = decipher.update(encrypted, 'base64', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  }

  static generateSignature(params: string | Record<string, any>, key: string): Promise<string> {
    return new Promise((resolve, reject) => {
      try {
        let stringParams = '';
        if (typeof params === 'string') {
          stringParams = params;
        } else if (typeof params === 'object' && params !== null) {
          stringParams = PaytmChecksum.getStringByParams(params);
        }
        const salt = PaytmChecksum.generateRandomString(4);
        const sha256 = crypto.createHash('sha256').update(stringParams + salt).digest('hex');
        const hash = sha256 + salt;
        const signature = PaytmChecksum.encrypt(hash, key);
        resolve(signature);
      } catch (err) {
        reject(err);
      }
    });
  }

  static verifySignature(params: string | Record<string, any>, key: string, checksum: string): boolean {
    if (!checksum) return false;
    try {
      let stringParams = '';
      if (typeof params === 'string') {
        stringParams = params;
      } else if (typeof params === 'object' && params !== null) {
        stringParams = PaytmChecksum.getStringByParams(params);
      }
      const decrypted = PaytmChecksum.decrypt(checksum, key);
      const salt = decrypted.substring(decrypted.length - 4);
      const sha256 = crypto.createHash('sha256').update(stringParams + salt).digest('hex');
      const calculatedHash = sha256 + salt;
      return calculatedHash === decrypted;
    } catch (err) {
      return false;
    }
  }

  private static generateRandomString(length: number): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    const bytes = crypto.randomBytes(length);
    for (let i = 0; i < length; i++) {
      result += chars.charAt(bytes[i] % chars.length);
    }
    return result;
  }

  private static getStringByParams(params: Record<string, any>): string {
    const sortedKeys = Object.keys(params).sort();
    let str = "";
    for (const key of sortedKeys) {
      const val = params[key];
      if (val !== undefined && val !== null && val !== 'null') {
        str += val;
      }
    }
    return str;
  }
}
