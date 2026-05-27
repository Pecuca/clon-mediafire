import nodemailer from 'nodemailer';

const smtpHost = process.env.SMTP_HOST;
const smtpPort = process.env.SMTP_PORT ? Number(process.env.SMTP_PORT) : undefined;
const smtpUser = process.env.SMTP_USER;
const smtpPass = process.env.SMTP_PASS;
const fromEmail = process.env.FROM_EMAIL || smtpUser;

let transporter: any = null;
if (smtpHost && smtpPort && smtpUser && smtpPass) {
  transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    auth: { user: smtpUser, pass: smtpPass },
  });
}

export async function sendEmail(to: string, subject: string, text: string, html?: string) {
  if (!transporter) {
    // Fallback: log email to console during development
    console.log('Email not sent (no SMTP configured).');
    console.log({ to, subject, text, html });
    return;
  }

  await transporter.sendMail({
    from: fromEmail,
    to,
    subject,
    text,
    html,
  });
}

export const getEmailTemplate = (token: string) => {
  return {
    subject: 'Password reset code',
    text: `Your password reset code is: ${token}. It expires in 15 minutes.`,
    html: `
      <div style="font-family:Arial,Helvetica,sans-serif;color:#222;">
        <div style="max-width:600px;margin:0 auto;padding:20px;border:1px solid #eaeaea;border-radius:8px;">
          <h2 style="color:#333;margin-top:0">Restablecimiento de contraseña</h2>
          <p>Hemos recibido una solicitud para restablecer la contraseña de tu cuenta.</p>
          <p style="font-size:18px;font-weight:700;letter-spacing:2px;margin:18px 0;padding:12px 16px;background:#f7f7f7;border-radius:6px;display:inline-block">${token}</p>
          <p>Este código expira en <strong>15 minutos</strong>. Si no solicitaste este cambio, puedes ignorar este correo.</p>
          <hr style="border:none;border-top:1px solid #eee;margin:20px 0" />
          <p style="font-size:12px;color:#777;margin:0">Si tienes problemas, responde a este correo o visita nuestro sitio.</p>
        </div>
      </div>
    `
  };
};
