import { BadRequestException, Controller, Post, Get, Put, Delete, Body, Param, Query, Req, Res, UseGuards, UseInterceptors, UploadedFile } from '@nestjs/common';
import { ArchiveService } from './archive.service';
import { AuthGuard } from '../auth/auth.guard';
import type { Request, Response } from 'express';
import { FileInterceptor } from '@nestjs/platform-express';

@Controller('file')
export class ArchiveController {
  constructor(private readonly archiveService: ArchiveService) {}

  @UseGuards(AuthGuard)
  @Post('upload/init')
  async initUpload() {
    return this.archiveService.initUpload();
  }

  @UseGuards(AuthGuard)
  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  async uploadFile(
    @Body('directoryId') directoryId: string,
    @Body('uploadToken') uploadToken: string,
    @Body('encryptedSymmetricKey') encryptedSymmetricKey: string,
    @Body('encryptedHash') encryptedHash: string,
    @UploadedFile() file: Express.Multer.File, 
    @Req() req: Request
  ) {
    const userId = Number((req.session as any).user.user_id);
    const dirId = directoryId && directoryId !== 'null' ? Number(directoryId) : null;
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip || null;
    
    return this.archiveService.uploadFile(
      userId, 
      dirId, 
      uploadToken, 
      encryptedSymmetricKey, 
      encryptedHash, 
      file, 
      ip
    );
  }

  @UseGuards(AuthGuard)
  @Get()
  async listMyFiles(@Query('directoryId') directoryId: string, @Req() req: Request) {
    const userId = Number((req.session as any).user.user_id);
    const dirId = directoryId === 'root' || !directoryId ? null : Number(directoryId);
    return this.archiveService.listUserFiles(userId, dirId);
  }

  @UseGuards(AuthGuard)
  @Get('public')
  async listPublicFiles(@Req() req: Request) {
    return this.archiveService.listPublicFiles();
  }

  @Get('shared/:token')
  async getSharedFile(@Param('token') token: string) {
    const archive = await this.archiveService.getSharedArchive(token);
    return {
      archive_id: archive.archive_id,
      archive_na: archive.archive_na,
      user_id: archive.user_id ?? archive.directory?.user_id,
      share_token: archive.share_token,
    };
  }



  @UseGuards(AuthGuard)
  @Get('download/:id')
  async downloadFile(
    @Param('id') id: string,
    @Req() req: Request,
    @Res() res: Response
  ) {
    const userId = Number((req.session as any).user.user_id);
    const archiveId = Number(id);
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip || null;
    const { buffer, filename, fileAuthTag, encryptedHashHeader } = await this.archiveService.downloadFile(userId, archiveId, ip);

    const safeName = encodeURIComponent(filename).replace(/'/g, '%27');

    res.setHeader('Content-Disposition', `attachment; filename="${filename}"; filename*=UTF-8''${safeName}`);
    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('x-file-auth-tag', fileAuthTag);
    res.setHeader('x-file-hash', encryptedHashHeader);
    res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition, x-file-auth-tag, x-file-hash');
    res.send(buffer);
  }

  @Get('download/shared/:token')
  async downloadSharedFile(
    @Param('token') token: string, 
    @Req() req: Request, 
    @Res() res: Response) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip || null;

    const { buffer, filename, fileAuthTag, encryptedHashHeader } = await this.archiveService.downloadFileByToken(token, ip);

    const safeName = encodeURIComponent(filename).replace(/'/g, '%27');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"; filename*=UTF-8''${safeName}`);
    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('x-file-auth-tag', fileAuthTag);
    res.setHeader('x-file-hash', encryptedHashHeader);
    res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition, x-file-auth-tag, x-file-hash');
    res.send(buffer);
  }

  @UseGuards(AuthGuard)
  @Put(':id/visibility')
  async changeVisibility(@Param('id') id: string, @Body('is_public') isPublic: boolean, @Req() req: Request) {
    const userId = Number((req.session as any).user.user_id);
    const archiveId = Number(id);
    return this.archiveService.changeVisibility(userId, archiveId, isPublic);
  }
  
  @Put(':id/rename')
  async renameArchive(@Param('id') id: string, @Body('name') newName: string, @Req() req: Request) {
    const userId = Number((req.session as any).user.user_id);
    const archiveId = Number(id);
    return this.archiveService.renameArchive(userId, archiveId, newName);
  }

  @UseGuards(AuthGuard)
  @Put(':id/move')
  async moveArchive(@Param('id') id: string, @Body('directoryId') newDirectoryId: string, @Req() req: Request) {
    const userId = Number((req.session as any).user.user_id);
    const archiveId = Number(id);
    const directoryId = newDirectoryId === 'root' || !newDirectoryId ? null : Number(newDirectoryId);
    return this.archiveService.moveArchive(userId, archiveId, directoryId);
  }

  @UseGuards(AuthGuard)
  @Delete(':id')
  async deleteArchive(@Param('id') id: string, @Req() req: Request) {
    const userId = Number((req.session as any).user.user_id);
    const archiveId = Number(id);
    return this.archiveService.deleteArchive(userId, archiveId);
  }
}
