import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { IsNull } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Archive } from './archive.entity';
import { UsersService } from '../users/users.service';
import { DirectoryService } from '../directory/directory.service';
import { Register } from '../register/register.entity';
import 'multer';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';

type SymmetricPayload = {
  key: string;
  iv: string;
  authTag: string;
};

@Injectable()
export class ArchiveService {
  private readonly serverPrivateKey: string;
  private readonly serverPublicKey: string;

  private pendingUploadKeys = new Map<string, string>();

  constructor(
    @InjectRepository(Archive)
    private archiveRepo: Repository<Archive>,
    @InjectRepository(Register)
    private registerRepo: Repository<Register>,
    private usersService: UsersService,
    private directoryService: DirectoryService,
  ) {
    const { privateKey, publicKey } = this.loadOrCreateServerKeyPair();
    this.serverPrivateKey = privateKey;
    this.serverPublicKey = publicKey;
  }

  private loadOrCreateServerKeyPair() {
    const keysDir = path.resolve(__dirname, '..', '..', 'keys');
    const privateKeyPath = path.join(keysDir, 'server-private.pem');
    const publicKeyPath = path.join(keysDir, 'server-public.pem');

    if (fs.existsSync(privateKeyPath) && fs.existsSync(publicKeyPath)) {
      return {
        privateKey: fs.readFileSync(privateKeyPath, 'utf8'),
        publicKey: fs.readFileSync(publicKeyPath, 'utf8'),
      };
    }

    if (!fs.existsSync(keysDir)) {
      fs.mkdirSync(keysDir, { recursive: true });
    }

    const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });

    fs.writeFileSync(privateKeyPath, privateKey, 'utf8');
    fs.writeFileSync(publicKeyPath, publicKey, 'utf8');

    return { privateKey, publicKey };
  }

  private encryptWithPublicKey(
    value: string,
    publicKey: string | crypto.KeyObject,
  ): string {
    const encrypted = crypto.publicEncrypt(
      {
        key: publicKey,
        padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
        oaepHash: 'sha256',
      },
      Buffer.from(value, 'utf8'),
    );
    return encrypted.toString('base64');
  }

  private decryptWithPrivateKey(value: string, privateKey: string): string {
    const decrypted = crypto.privateDecrypt(
      {
        key: privateKey,
        padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
        oaepHash: 'sha256',
      },
      Buffer.from(value, 'base64'),
    );
    return decrypted.toString('utf8');
  }

  private tryDecryptStoredValue(
    value: string,
    privateKey: string,
  ): string | null {
    try {
      return this.decryptWithPrivateKey(value, privateKey);
    } catch {
      return null;
    }
  }

  private parseClientPublicKey(
    clientPublicKeyBase64: string,
  ): crypto.KeyObject {
    try {
      return crypto.createPublicKey({
        key: Buffer.from(clientPublicKeyBase64, 'base64'),
        format: 'der',
        type: 'spki',
      });
    } catch {
      throw new BadRequestException('Invalid client public key');
    }
  }

  private tryParseSymmetricPayload(value: string): SymmetricPayload | null {
    try {
      const parsed = JSON.parse(value) as Partial<SymmetricPayload>;
      if (!parsed.key || !parsed.iv || !parsed.authTag) {
        return null;
      }
      return {
        key: parsed.key,
        iv: parsed.iv,
        authTag: parsed.authTag,
      };
    } catch {
      return null;
    }
  }

  private parseStoredSymmetricPayload(value: string): SymmetricPayload {
    const direct = this.tryParseSymmetricPayload(value);
    if (direct) return direct;

    try {
      const decoded = Buffer.from(value, 'base64').toString('utf8');
      const fromBase64 = this.tryParseSymmetricPayload(decoded);
      if (fromBase64) return fromBase64;
    } catch {
      // ignore and throw explicit error below
    }

    throw new BadRequestException('Stored symmetric payload is invalid');
  }

  private getArchivePrivateKey(archive: Archive): string {
    if (archive.private_key && archive.private_key.trim()) {
      return archive.private_key;
    }
    return archive.private_key || this.serverPrivateKey;
  }

  private async getOwnedDirectory(userId: number, directoryId: number | null) {
    if (directoryId === null || directoryId === undefined) return null;

    const directory = await this.directoryService.findByIdAndUser(
      userId,
      directoryId,
    );
    if (!directory) {
      throw new NotFoundException('Directory not found');
    }

    return directory;
  }

  private async getOwnedArchive(userId: number, archiveId: number) {
    const archive = await this.archiveRepo.findOne({
      where: { archive_id: archiveId },
      relations: ['directory'],
    });

    // Allow if archive belongs to user directly (root) or via directory
    const ownedByDirectory = archive?.directory?.user_id === userId;
    const ownedDirectly = archive?.user_id === userId;
    if (!archive || (!ownedByDirectory && !ownedDirectly)) {
      throw new NotFoundException('Archive not found');
    }

    return archive;
  }

  async initUpload() {
    // Paso 3: Generación llaves server por archivo
    const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });

    const uploadToken = crypto.randomUUID();
    // Guardamos la llave privada temporalmente asociada a este intento de subida
    this.pendingUploadKeys.set(uploadToken, privateKey);

    // Paso 4: Response llave publica de server
    return { uploadToken, publicKey };
  }

  async uploadFile(
    userId: number,
    directoryId: number | null,
    uploadToken: string,
    encryptedSymmetricKey: string,
    encryptedHash: string,
    file: Express.Multer.File,
    ip?: string | null,
  ) {
    if (!file) throw new BadRequestException('File is required');

    const user = await this.usersService.findById(userId);
    if (!user) throw new NotFoundException('User not found');

    const directory = await this.getOwnedDirectory(userId, directoryId);

    // Recuperar la llave privada específica de este archivo
    const privateKey = this.pendingUploadKeys.get(uploadToken);
    if (!privateKey) {
      throw new BadRequestException(
        'Token de subida inválido o expirado. Reinicie la subida.',
      );
    }
    // Limpiamos la caché inmediatamente
    this.pendingUploadKeys.delete(uploadToken);

    // Paso 8: Desencriptar hash y llave simétrica con llave privada
    const decryptedSymmetricStr = this.decryptWithPrivateKey(
      encryptedSymmetricKey,
      privateKey,
    );
    const decryptedHash = this.decryptWithPrivateKey(encryptedHash, privateKey);

    let symmetricPayload: SymmetricPayload;
    try {
      symmetricPayload = JSON.parse(decryptedSymmetricStr);
    } catch {
      throw new BadRequestException('Payload simétrico inválido');
    }

    // Paso 9: Desencriptar archivo con llave simétrica
    const decipher = crypto.createDecipheriv(
      'aes-256-gcm',
      Buffer.from(symmetricPayload.key, 'hex'),
      Buffer.from(symmetricPayload.iv, 'hex'),
    );
    decipher.setAuthTag(Buffer.from(symmetricPayload.authTag, 'hex'));

    let decryptedBuffer: Buffer;
    try {
      // file.buffer aquí contiene SOLO el ciphertext enviado por el cliente
      decryptedBuffer = Buffer.concat([
        decipher.update(file.buffer),
        decipher.final(),
      ]);
    } catch (e) {
      throw new BadRequestException(
        'Fallo al desencriptar el archivo. Llave o AuthTag corruptos.',
      );
    }

    // Paso 10: Rehash y comparación
    const calculatedHash = crypto
      .createHash('sha256')
      .update(decryptedBuffer)
      .digest('hex');
    if (calculatedHash !== decryptedHash.toLowerCase()) {
      throw new BadRequestException(
        'Integridad comprometida: el hash no coincide',
      );
    }

    // Paso 11: Guardar archivo encriptado en HD
    const uploadDir = path.resolve(__dirname, '..', '..', 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    const fileName = `${Date.now()}-${file.originalname}.enc`;
    const filePath = path.join(uploadDir, fileName);

    // Guardamos el file.buffer original (que ya viene encriptado desde el navegador)
    fs.writeFileSync(filePath, file.buffer);

    // Paso 12: Guardar hash y llave simétrica encriptados en DB
    const archive = this.archiveRepo.create({
      archive_na: file.originalname,
      symmetric_key: encryptedSymmetricKey, // Se guarda ya encriptado con la llave pública única
      hash: encryptedHash, // Se guarda ya encriptado
      private_key: privateKey, // Asignamos la llave privada ÚNICA de este archivo a la DB
      file_path: filePath,
      user_id: userId,
      ...(directory ? { directory, directory_id: directory.directory_id } : {}),
    });

    const saved = await this.archiveRepo.save(archive);

    try {
      await this.registerRepo.save({
        register_type_id: 1,
        register_type_na: 'subida',
        user_id: userId,
        archive_id: saved.archive_id,
        archive_na: saved.archive_na,
        ip_address: ip ?? null,
        details: null,
        success: true,
      } as any);
    } catch (err) {
      console.error('Failed to create register entry for upload', err);
    }

    return saved;
  }

  async downloadFile(
    userId: number,
    archiveId: number,
    ip?: string | null,
  ) {
    // Find the archive — may be owned or public
    const archive = await this.archiveRepo.findOne({
      where: { archive_id: archiveId },
      relations: ['directory'],
    });
    if (!archive) throw new NotFoundException('Archive not found');

    const ownedByDirectory = archive.directory?.user_id === userId;
    const ownedDirectly = archive.user_id === userId;
    const isOwner = ownedByDirectory || ownedDirectly;

    if (!isOwner && !archive.is_public) {
      throw new ForbiddenException('This file is private');
    }

    return this.getEncryptedArchivePayload(
      archive,
      userId,
      ip,
    );
  }

  async listUserFiles(userId: number, directoryId?: number | null) {
    const where: any = { user_id: userId };
    if (directoryId === null || directoryId === undefined) {
      // root-level files: no directory assigned
      where.directory_id = IsNull();
    } else {
      where.directory_id = directoryId;
    }
    return this.archiveRepo.find({
      where,
      select: [
        'archive_id',
        'archive_na',
        'hash',
        'is_public',
        'user_id',
        'directory_id',
        'share_token',
      ],
    });
  }

  async listPublicFiles() {
    return this.archiveRepo.find({
      where: { is_public: true },
      select: [
        'archive_id',
        'archive_na',
        'hash',
        'is_public',
        'user_id',
        'directory_id',
        'share_token',
      ],
    });
  }

  async getSharedArchive(token: string) {
    const archive = await this.archiveRepo.findOne({
      where: { share_token: token, is_public: true },
      relations: ['directory'],
    });
    if (!archive) throw new NotFoundException('Shared file not found');

    return archive;
  }

  async downloadFileByToken(
    token: string,
    ip?: string | null,
  ) {
    const archive = await this.getSharedArchive(token);
    return this.getEncryptedArchivePayload(
      archive,
      null,
      ip,
    );
  }

  private async getEncryptedArchivePayload(
    archive: Archive,
    actorUserId?: number | null,
    ip?: string | null,
  ) {
    if (!fs.existsSync(archive.file_path)) {
      throw new NotFoundException('Encrypted file not found on disk');
    }

    const encryptedBuffer = fs.readFileSync(archive.file_path);
    const archivePrivateKey = this.getArchivePrivateKey(archive);

    const decryptedSymmetricPayload =
      this.tryDecryptStoredValue(archive.symmetric_key, archivePrivateKey) ??
      archive.symmetric_key;

    const plainHash =
      this.tryDecryptStoredValue(archive.hash, archivePrivateKey) ??
      archive.hash;

    const symmetricPayloadBase64 = Buffer.from(decryptedSymmetricPayload, 'utf8').toString('base64');
    const hashBase64 = Buffer.from(plainHash, 'utf8').toString('base64');

    try {
      await this.registerRepo.save({
        register_type_id: 2,
        register_type_na: 'descarga',
        user_id: actorUserId ?? null,
        archive_id: archive.archive_id,
        archive_na: archive.archive_na,
        ip_address: ip ?? null,
        details: null,
        success: true,
      } as any);
    } catch (err) {
      console.error('Failed to create register entry for download', err);
    }

    return {
      buffer: encryptedBuffer,
      filename: archive.archive_na,
      fileAuthTag: symmetricPayloadBase64,
      encryptedHashHeader: hashBase64,
    };
  }

  // ── Helpers ──────────────────

  async changeVisibility(userId: number, archiveId: number, isPublic: boolean) {
    const archive = await this.getOwnedArchive(userId, archiveId);
    archive.is_public = isPublic;
    if (isPublic && !archive.share_token) {
      archive.share_token = crypto.randomUUID();
    }
    if (!isPublic) {
      archive.share_token = null;
    }
    await this.archiveRepo.save(archive);
    return {
      archive_id: archive.archive_id,
      archive_na: archive.archive_na,
      is_public: archive.is_public,
      share_token: archive.share_token,
    };
  }

  async renameArchive(userId: number, archiveId: number, newName: string) {
    const archive = await this.getOwnedArchive(userId, archiveId);
    archive.archive_na = newName;
    return this.archiveRepo.save(archive);
  }

  async moveArchive(
    userId: number,
    archiveId: number,
    newDirectoryId: number | null,
  ) {
    const archive = await this.getOwnedArchive(userId, archiveId);
    const targetDirectory = await this.getOwnedDirectory(
      userId,
      newDirectoryId,
    );

    archive.directory = targetDirectory;
    archive.directory_id = targetDirectory?.directory_id ?? null;
    return this.archiveRepo.save(archive);
  }

  async deleteArchive(userId: number, archiveId: number) {
    const archive = await this.getOwnedArchive(userId, archiveId);

    // Preserve audit history while allowing archive deletion.
    await this.registerRepo
      .createQueryBuilder()
      .update(Register)
      .set({ archive_id: null })
      .where('archive_id = :archiveId', { archiveId })
      .execute();

    if (fs.existsSync(archive.file_path)) {
      fs.unlinkSync(archive.file_path);
    }

    await this.archiveRepo.remove(archive);
    return { success: true };
  }
}
