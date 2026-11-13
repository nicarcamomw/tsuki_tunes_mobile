/// Accounts that see everything unlockable (every Oni mask, the Moon Mix
/// outside the full moon) without earning it. It only changes what this
/// app shows them: no unlock is written to their Firestore document, so
/// their real progress stays as it is.
const adminEmails = {'ni.carcamo.hernandez@gmail.com'};

bool isAdminEmail(String? email) =>
    email != null && adminEmails.contains(email.trim().toLowerCase());
