import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { Directory } from './directory.entity';

@Injectable()
export class DirectoryService {
  constructor(
    @InjectRepository(Directory)
    private directoryRepo: Repository<Directory>,
  ) {}

  async createDirectory(userId: number, name: string, parentId?: number) {
    let parent = null;
    if (parentId !== undefined && parentId !== null) {
      parent = await this.directoryRepo.findOne({ where: { directory_id: parentId, user_id: userId } });
      if (!parent) throw new NotFoundException('Parent directory not found');
    }

    const dir = this.directoryRepo.create({
      directory_name: name,
      user_id: userId,
      ...(parent ? { parent } : {})
    });

    return this.directoryRepo.save(dir);
  }

  async listDirectories(userId: number, parentId?: number) {
    if (parentId !== undefined && parentId !== null) {
      return this.directoryRepo.find({ where: { user_id: userId, parent: { directory_id: parentId } } });
    } else {
      return this.directoryRepo.find({ where: { user_id: userId, parent: IsNull() } });
    }
  }

  async findByIdAndUser(userId: number, id: number) {
    return this.directoryRepo.findOne({ where: { directory_id: id, user_id: userId } });
  }

  async renameDirectory(userId: number, id: number, newName: string) {
    const dir = await this.directoryRepo.findOne({ where: { directory_id: id, user_id: userId } });
    if (!dir) throw new NotFoundException('Directory not found');
    
    dir.directory_name = newName;
    return this.directoryRepo.save(dir);
  }

  async deleteDirectory(userId: number, id: number) {
    const dir = await this.directoryRepo.findOne({ where: { directory_id: id, user_id: userId } });
    if (!dir) throw new NotFoundException('Directory not found');
    
    await this.directoryRepo.remove(dir);
    return { success: true };
  }
}
