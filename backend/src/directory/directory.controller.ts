import { Controller, Post, Get, Put, Delete, Body, Param, Req, UseGuards } from '@nestjs/common';
import { DirectoryService } from './directory.service';
import { AuthGuard } from '../auth/auth.guard';
import type { Request } from 'express';

@UseGuards(AuthGuard)
@Controller('directory')
export class DirectoryController {
  constructor(private readonly directoryService: DirectoryService) {}

  @Post()
  async createDirectory(@Body() body: any, @Req() req: Request) {
    const userId = Number((req.session as any).user.user_id);
    const parentId = body.parentId ? Number(body.parentId) : undefined;
    return this.directoryService.createDirectory(userId, body.name, parentId);
  }

  @Get()
  async listRootDirectories(@Req() req: Request) {
    const userId = Number((req.session as any).user.user_id);
    return this.directoryService.listDirectories(userId);
  }

  @Get(':parentId')
  async listDirectories(@Param('parentId') parentId: string, @Req() req: Request) {
    const userId = Number((req.session as any).user.user_id);
    return this.directoryService.listDirectories(userId, Number(parentId));
  }

  @Put(':id')
  async renameDirectory(@Param('id') id: string, @Body() body: any, @Req() req: Request) {
    const userId = Number((req.session as any).user.user_id);
    return this.directoryService.renameDirectory(userId, Number(id), body.name);
  }

  @Delete(':id')
  async deleteDirectory(@Param('id') id: string, @Req() req: Request) {
    const userId = Number((req.session as any).user.user_id);
    return this.directoryService.deleteDirectory(userId, Number(id));
  }
}
