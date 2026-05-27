import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import * as dotenv from 'dotenv';
dotenv.config();
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { DirectoryModule } from './directory/directory.module';
import { ArchiveModule } from './archive/archive.module';
import { UsersModule } from './users/users.module';
import { User } from './users/user.entity';
import { Directory } from './directory/directory.entity';
import { Archive } from './archive/archive.entity';
import { Register } from './register/register.entity';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: 'db',
      port: 5432,
      username: 'postgres',
      password: '1234',
      database: 'archive',
      entities: [User, Directory, Archive, Register],
      synchronize: true, // auto-create schema
    }),
    AuthModule, 
    DirectoryModule, 
    ArchiveModule, 
    UsersModule
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
