import { Controller, Post, Body, Req, Res, HttpCode, HttpStatus } from '@nestjs/common';
import { AuthService } from './auth.service';
import type { Request, Response } from 'express';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('register')
  async register(@Body() body: any) {
    const { name, email, password } = body;
    return this.authService.register(name, email, password);
  }

  @HttpCode(HttpStatus.OK)
  @Post('login')
  async login(@Body() body: any, @Req() req: Request) {
    const { email, password } = body;
    const user = await this.authService.login(email, password);
    (req.session as any).user = user;
    return user;
  }

  @HttpCode(HttpStatus.OK)
  @Post('logout')
  async logout(@Req() req: Request, @Res() res: Response) {
    req.session.destroy((err) => {
      res.clearCookie('connect.sid');
      res.send({ message: 'Logged out successfully' });
    });
  }

  @Post('forget-password')
  async forgetPassword(@Body('email') email: string) {
    return this.authService.forgetPassword(email);
  }

  @Post('verify-reset')
  async verifyReset(@Body() body: { email: string; token: string }) {
    const { email, token } = body;
    return this.authService.verifyResetToken(email, token);
  }

  @Post('reset-password')
  async resetPassword(@Body() body: { email: string; token: string; newPassword: string }) {
    const { email, token, newPassword } = body;
    return this.authService.resetPassword(email, token, newPassword);
  }
}
