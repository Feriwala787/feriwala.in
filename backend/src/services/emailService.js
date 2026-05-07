const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: 'smtp.zoho.in',
  port: 465,
  secure: true,
  auth: {
    user: process.env.SMTP_USER || 'verify@feriwala.in',
    pass: process.env.SMTP_PASS || 'WXYvvuiZ6eij',
  },
});

async function sendOtpEmail({ to, otp, name = '' }) {
  await transporter.sendMail({
    from: `"Feriwala" <${process.env.SMTP_USER || 'verify@feriwala.in'}>`,
    to,
    subject: 'Your Feriwala Password Reset OTP',
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#fff;border-radius:12px;border:1px solid #eee">
        <h2 style="color:#F47721;margin-bottom:8px">🛒 Feriwala</h2>
        <p style="color:#333">Hi ${name || 'there'},</p>
        <p style="color:#555">Use the OTP below to reset your password. It expires in <strong>10 minutes</strong>.</p>
        <div style="background:#F47721;color:#fff;font-size:32px;font-weight:bold;letter-spacing:8px;text-align:center;padding:20px;border-radius:8px;margin:24px 0">
          ${otp}
        </div>
        <p style="color:#888;font-size:13px">If you didn't request this, ignore this email. Your password won't change.</p>
        <hr style="border:none;border-top:1px solid #eee;margin:24px 0"/>
        <p style="color:#aaa;font-size:12px">Feriwala — Quick Commerce for Clothes</p>
      </div>
    `,
  });
}

async function sendWelcomeEmail({ to, name, role, password }) {
  await transporter.sendMail({
    from: `"Feriwala" <${process.env.SMTP_USER || 'verify@feriwala.in'}>`,
    to,
    subject: `Welcome to Feriwala — Your ${role} account is ready`,
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#fff;border-radius:12px;border:1px solid #eee">
        <h2 style="color:#F47721;margin-bottom:8px">🛒 Feriwala</h2>
        <p style="color:#333">Hi ${name},</p>
        <p style="color:#555">Your <strong>${role}</strong> account has been created.</p>
        <div style="background:#f9f9f9;border-radius:8px;padding:16px;margin:16px 0">
          <p style="margin:4px 0;color:#333"><strong>Email:</strong> ${to}</p>
          <p style="margin:4px 0;color:#333"><strong>Temporary Password:</strong> <code style="background:#eee;padding:2px 6px;border-radius:4px">${password}</code></p>
        </div>
        <p style="color:#555">Please login and change your password immediately.</p>
        <a href="https://portal.feriwala.in" style="display:inline-block;background:#F47721;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:bold;margin-top:8px">Open Portal</a>
        <hr style="border:none;border-top:1px solid #eee;margin:24px 0"/>
        <p style="color:#aaa;font-size:12px">Feriwala — Quick Commerce for Clothes</p>
      </div>
    `,
  });
}

module.exports = { sendOtpEmail, sendWelcomeEmail };
