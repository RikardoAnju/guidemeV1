exports.resetPassword = functions.https.onCall(async (data, context) => {
  const { email, newPassword } = data;

  if (!email || !newPassword) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email dan password baru harus diisi.'
    );
  }

  try {
    const userRecord = await admin.auth().getUserByEmail(email);

    await admin.auth().updateUser(userRecord.uid, {
      password: newPassword,
    });

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
