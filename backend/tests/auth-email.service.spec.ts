import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from '../src/auth/auth.service';
import { UsersService } from '../src/users/users.service';
import { BadRequestException } from '@nestjs/common';

jest.mock('../src/lib/email', () => ({
  sendEmail: jest.fn(),
}));

const { sendEmail } = require('../src/lib/email') as { sendEmail: jest.Mock };

describe('AuthService email reset flow', () => {
  let service: AuthService;
  let usersService: Partial<Record<keyof UsersService, jest.Mock>>;

  beforeEach(async () => {
    usersService = {
      findByEmail: jest.fn(),
      save: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: usersService },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    sendEmail.mockClear();
    usersService.findByEmail!.mockClear();
    usersService.save!.mockClear();
  });

  it('should send reset email, verify token and reset password', async () => {
    const user = {
      user_id: 1,
      user_na: 'Test User',
      user_mail: 'test@example.com',
      user_pass: 'old-password-hash',
      public_key: 'pub',
      private_key: 'priv',
      reset_token: null,
      reset_token_expires: null,
    } as any;

    usersService.findByEmail!.mockResolvedValue(user);
    usersService.save!.mockImplementation(async (savedUser: any) => savedUser);

    const forgotResult = await service.forgetPassword('test@example.com');
    expect(forgotResult).toEqual({ success: true });
    expect(user.reset_token).toMatch(/^[0-9]{6}$/);
    expect(user.reset_token_expires).toBeInstanceOf(Date);
    expect(usersService.save).toHaveBeenCalledWith(user);
    expect(sendEmail).toHaveBeenCalledWith(
      'test@example.com',
      expect.any(String),
      expect.stringContaining(user.reset_token),
      expect.stringContaining(user.reset_token),
    );

    const verifyResult = await service.verifyResetToken('test@example.com', user.reset_token);
    expect(verifyResult).toEqual({ success: true });

    const resetResult = await service.resetPassword('test@example.com', user.reset_token, 'newPassword');
    expect(resetResult).toEqual({ success: true });
    expect(user.user_pass).not.toEqual('old-password-hash');
    expect(user.reset_token).toBeNull();
    expect(user.reset_token_expires).toBeNull();
    expect(usersService.save).toHaveBeenCalledWith(user);
  });

  it('should reject resetPassword when token mismatch', async () => {
    usersService.findByEmail!.mockResolvedValue({
      reset_token: '123456',
      reset_token_expires: new Date(Date.now() + 1000 * 60),
    } as any);

    await expect(service.resetPassword('test@example.com', '000000', 'newPassword')).rejects.toThrow(BadRequestException);
  });
});
