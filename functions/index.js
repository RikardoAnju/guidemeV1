const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.resetPasswordByEmail = functions.https.onRequest(async (req, res) => {
  const { email, newPassword } = req.body;

  if (!email || !newPassword) {
    return res.status(500).json({
      message: "Gagal reset password",
      error: error.message,
    });
  }

  try {
    const user = await admin.auth().getUserByEmail(email);

    await admin.auth().updateUser(user.uid, {
      password: newPassword,
    });

    return res.status(200).json({ message: "Password berhasil direset" });
  } catch (error) {
    console.error("Error reset password:", error);
    return res.status(500).json({ message: "Gagal reset password", error: error.message });
  }
});
