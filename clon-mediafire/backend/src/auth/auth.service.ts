import { Injectable, UnauthorizedException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { sendEmail } from '../lib/email';
import { User } from '../users/user.entity';
import { getEmailTemplate } from '../lib/email';

@Injectable()
export class AuthService {
  constructor(private usersService: UsersService) {}

  async register(name: string, email: string, pass: string) {
    const existingUser = await this.usersService.findByEmail(email);
    if (existingUser) {
      throw new BadRequestException('User already exists');
    }

    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(pass, saltRounds);

    const user = await this.usersService.create({
      user_na: name,
      user_mail: email,
      user_pass: hashedPassword
    });

    return {
      user_id: user.user_id,
      user_na: user.user_na,
      user_mail: user.user_mail
    };
  }

  async login(email: string, pass: string) {
    const user = await this.usersService.findByEmail(email);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isMatch = await bcrypt.compare(pass, user.user_pass);
    if (!isMatch) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return {
      user_id: user.user_id,
      user_na: user.user_na,
      user_mail: user.user_mail
    };
  }

  async forgetPassword(email: string) {
    const user = await this.usersService.findByEmail(email);
    if (!user) {
      // Do not reveal that user doesn't exist — for security, respond success
      return { success: true };
    }

    // generate 6-digit token
    const token = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    user.reset_token = token;
    user.reset_token_expires = expires;
    await this.usersService.save(user);

    const { subject, text, html } = getEmailTemplate(token);

    try {
      await sendEmail(email, subject, text, html);
    } catch (err) {
      console.error('Failed to send reset email', err);
    }

    return { success: true };
  }

  async verifyResetToken(email: string, token: string) {
    const user = await this.usersService.findByEmail(email);
    if (!user) throw new BadRequestException('Invalid token');

    if (!user.reset_token || user.reset_token !== token) throw new BadRequestException('Invalid token');
    if (!user.reset_token_expires || user.reset_token_expires.getTime() < Date.now()) throw new BadRequestException('Token expired');

    return { success: true };
  }

  async resetPassword(email: string, token: string, newPassword: string) {
    const user = await this.usersService.findByEmail(email);
    if (!user) throw new BadRequestException('Invalid token');

    if (!user.reset_token || user.reset_token !== token) throw new BadRequestException('Invalid token');
    if (!user.reset_token_expires || user.reset_token_expires.getTime() < Date.now()) throw new BadRequestException('Token expired');

    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);

    user.user_pass = hashedPassword;
    user.reset_token = null;
    user.reset_token_expires = null;
    await this.usersService.save(user);

    return { success: true };
  }
}
