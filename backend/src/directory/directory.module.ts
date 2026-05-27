import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DirectoryService } from './directory.service';
import { DirectoryController } from './directory.controller';
import { Directory } from './directory.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Directory])],
  providers: [DirectoryService],
  controllers: [DirectoryController],
  exports: [DirectoryService],
})
export class DirectoryModule {}
