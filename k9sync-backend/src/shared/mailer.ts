import nodemailer, { Transporter } from 'nodemailer';
import { logger } from './logger.js';

let _transporter: Transporter | null = null;
let _usingEthereal = false;

async function getTransporter(): Promise<Transporter> {
  if (_transporter) return _transporter;

  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD } = process.env;
  if (SMTP_HOST && SMTP_PORT && SMTP_USER && SMTP_PASSWORD) {
    _transporter = nodemailer.createTransport({
      host: SMTP_HOST,
      port: Number(SMTP_PORT),
      secure: Number(SMTP_PORT) === 465,
      auth: { user: SMTP_USER, pass: SMTP_PASSWORD },
    });
    logger.info({ host: SMTP_HOST }, 'Mailer: using configured SMTP');
    return _transporter;
  }

  // No SMTP_* env vars set — dev fallback: Ethereal, a throwaway test inbox
  // (nodemailer generates credentials on the fly, nothing to configure, no
  // real mailbox needed). Emails sent this way are NOT delivered anywhere
  // real; each send logs a preview URL to view it instead.
  _usingEthereal = true;
  const testAccount = await nodemailer.createTestAccount();
  _transporter = nodemailer.createTransport({
    host: testAccount.smtp.host,
    port: testAccount.smtp.port,
    secure: testAccount.smtp.secure,
    auth: { user: testAccount.user, pass: testAccount.pass },
  });
  logger.warn(
    { user: testAccount.user },
    'Mailer: no SMTP_* env vars set — using an Ethereal test inbox (emails are NOT delivered for real; check the logged preview URL on each send)',
  );
  return _transporter;
}

async function sendMail(to: string, subject: string, text: string, html: string): Promise<void> {
  const transporter = await getTransporter();
  const info = await transporter.sendMail({
    from: process.env.SMTP_FROM ?? 'K9 Sync <no-reply@k9sync.app>',
    to,
    subject,
    text,
    html,
  });
  if (_usingEthereal) {
    logger.info(
      { to, previewUrl: nodemailer.getTestMessageUrl(info) },
      'Mailer: Ethereal preview URL (dev only — not a real inbox)',
    );
  }
}

function passwordResetEmailContent(code: string, expiresInMinutes: number) {
  const subject = 'K9 Sync — Code de réinitialisation de mot de passe';
  const text =
    `Voici votre code de réinitialisation : ${code}\n\n` +
    `Ce code est valable ${expiresInMinutes} minutes.\n\n` +
    `Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet ` +
    `email — votre mot de passe restera inchangé.`;
  const html = `
    <p>Voici votre code de réinitialisation :</p>
    <p style="font-size: 28px; font-weight: bold; letter-spacing: 4px;">${code}</p>
    <p>Ce code est valable <strong>${expiresInMinutes} minutes</strong>.</p>
    <p>Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet
    email — votre mot de passe restera inchangé.</p>
  `;
  return { subject, text, html };
}

/**
 * Exported as an object (same reasoning as pushNotifications and
 * mqttPublisher): tests can swap the method with
 * `t.mock.method(mailer, 'sendPasswordResetEmail', ...)` without touching
 * the network or Ethereal.
 */
export const mailer = {
  async sendPasswordResetEmail(to: string, code: string, expiresInMinutes: number): Promise<void> {
    const { subject, text, html } = passwordResetEmailContent(code, expiresInMinutes);
    await sendMail(to, subject, text, html);
  },
};
