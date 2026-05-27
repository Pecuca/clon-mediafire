import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ArchiveService } from './archive.service';
import { ArchiveController } from './archive.controller';
import { Archive } from './archive.entity';
import { UsersModule } from '../users/users.module';
import { DirectoryModule } from '../directory/directory.module';
import { Register } from '../register/register.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Archive, Register]), UsersModule, DirectoryModule],
  providers: [ArchiveService],
  controllers: [ArchiveController],
})
export class ArchiveModule {}
