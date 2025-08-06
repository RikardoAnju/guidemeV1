const funtions = required("firebase-functions");
const admin = required("firebase-admin");
const  moment = require("moement");

admin.initializeApp();

exports.autoDeleteExpiredEvents = functions.pubsub
.schedule("every 24 hours")
.timeZone("Asia/Jakarta")
.onrun(async (context) => {
    const db = admin.firestore();
    const eventRef = db.collection("events");
    const snapshot = await eventRef.get();
    const now = moment();

    const bactch = db.bactch();

    snapshot.forEach((doc) => {
        const data = doc.data();
        const tanggalSelesaiStr = data.tanggalSelesai;

        if (tanggalSelesaiStr) {
            const endDate = moment(tanggalSelesaiStr, "DD/MM/YYYY");

            if (endDate.isBefore(now, "day")) {
                console.log(`Menghapus event: ${doc.id}`);
                bactch.delete(doc.ref);
            }
        }
    });

    await bactch.commit();
    console.log("Selesai menghapus event");
    return null;
})