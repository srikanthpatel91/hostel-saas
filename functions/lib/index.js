"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onInvoiceCreated = exports.onCheckoutRequestUpdated = exports.onCheckoutRequestCreated = exports.onNoticeCreated = exports.onComplaintUpdated = exports.onComplaintCreated = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
// ---------- Helpers ----------
async function getOwnerToken(hostelId) {
    var _a, _b, _c;
    const hostelSnap = await db.collection("hostels").doc(hostelId).get();
    const ownerId = (_a = hostelSnap.data()) === null || _a === void 0 ? void 0 : _a.ownerId;
    if (!ownerId)
        return null;
    const userSnap = await db.collection("users").doc(ownerId).get();
    return (_c = (_b = userSnap.data()) === null || _b === void 0 ? void 0 : _b.fcmToken) !== null && _c !== void 0 ? _c : null;
}
async function getTenantToken(hostelId, guestId) {
    var _a, _b, _c;
    const guestSnap = await db
        .collection("hostels")
        .doc(hostelId)
        .collection("guests")
        .doc(guestId)
        .get();
    const linkedUserId = (_a = guestSnap.data()) === null || _a === void 0 ? void 0 : _a.linkedUserId;
    if (!linkedUserId)
        return null;
    const userSnap = await db.collection("users").doc(linkedUserId).get();
    return (_c = (_b = userSnap.data()) === null || _b === void 0 ? void 0 : _b.fcmToken) !== null && _c !== void 0 ? _c : null;
}
async function getAllTenantTokens(hostelId) {
    var _a;
    const guestsSnap = await db
        .collection("hostels")
        .doc(hostelId)
        .collection("guests")
        .where("isActive", "==", true)
        .where("linkedUserId", "!=", null)
        .get();
    const tokens = [];
    for (const guestDoc of guestsSnap.docs) {
        const linkedUserId = guestDoc.data().linkedUserId;
        const userSnap = await db.collection("users").doc(linkedUserId).get();
        const token = (_a = userSnap.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
        if (token)
            tokens.push(token);
    }
    return tokens;
}
async function send(token, title, body, data) {
    try {
        await messaging.send({
            token,
            notification: { title, body },
            data,
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default" } } },
        });
    }
    catch (err) {
        console.error("FCM send failed:", err);
    }
}
async function sendToMany(tokens, title, body, data) {
    if (tokens.length === 0)
        return;
    try {
        await messaging.sendEachForMulticast({
            tokens,
            notification: { title, body },
            data,
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default" } } },
        });
    }
    catch (err) {
        console.error("FCM multicast failed:", err);
    }
}
// ---------- Triggers ----------
// 1. New complaint → notify owner
exports.onComplaintCreated = (0, firestore_1.onDocumentCreated)("hostels/{hostelId}/complaints/{complaintId}", async (event) => {
    var _a;
    const hostelId = event.params.hostelId;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const token = await getOwnerToken(hostelId);
    if (!token)
        return;
    await send(token, "New Complaint", `${data.guestName} (Room ${data.roomNumber}): ${data.category}`, { type: "complaint", hostelId });
});
// 2. Complaint resolved → notify tenant
exports.onComplaintUpdated = (0, firestore_1.onDocumentUpdated)("hostels/{hostelId}/complaints/{complaintId}", async (event) => {
    var _a, _b;
    const hostelId = event.params.hostelId;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!before || !after)
        return;
    if (before.status === after.status)
        return;
    if (after.status === "resolved") {
        const token = await getTenantToken(hostelId, after.guestId);
        if (!token)
            return;
        await send(token, "Complaint Resolved", `Your ${after.category} complaint has been resolved.`, { type: "complaint_resolved", hostelId });
    }
});
// 3. New notice → notify all active tenants
exports.onNoticeCreated = (0, firestore_1.onDocumentCreated)("hostels/{hostelId}/notices/{noticeId}", async (event) => {
    var _a;
    const hostelId = event.params.hostelId;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const tokens = await getAllTenantTokens(hostelId);
    await sendToMany(tokens, data.title, data.body, {
        type: "notice",
        hostelId,
    });
});
// 4. Checkout request submitted → notify owner
exports.onCheckoutRequestCreated = (0, firestore_1.onDocumentCreated)("hostels/{hostelId}/checkout_requests/{requestId}", async (event) => {
    var _a;
    const hostelId = event.params.hostelId;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const token = await getOwnerToken(hostelId);
    if (!token)
        return;
    await send(token, "Checkout Request", `${data.guestName} (Room ${data.roomNumber}) wants to check out.`, { type: "checkout_request", hostelId });
});
// 5. Checkout approved/denied → notify tenant
exports.onCheckoutRequestUpdated = (0, firestore_1.onDocumentUpdated)("hostels/{hostelId}/checkout_requests/{requestId}", async (event) => {
    var _a, _b;
    const hostelId = event.params.hostelId;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!before || !after)
        return;
    if (before.status === after.status)
        return;
    if (after.status === "approved" || after.status === "denied") {
        const token = await getTenantToken(hostelId, after.guestId);
        if (!token)
            return;
        const approved = after.status === "approved";
        await send(token, approved ? "Checkout Approved" : "Checkout Denied", approved
            ? "Your checkout request has been approved."
            : "Your checkout request was denied. Please contact the owner.", { type: "checkout_updated", hostelId, status: after.status });
    }
});
// 6. New invoice generated → notify tenant
exports.onInvoiceCreated = (0, firestore_1.onDocumentCreated)("hostels/{hostelId}/invoices/{invoiceId}", async (event) => {
    var _a;
    const hostelId = event.params.hostelId;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const token = await getTenantToken(hostelId, data.guestId);
    if (!token)
        return;
    const amount = data.gstEnabled ? data.totalWithGst : data.amount;
    await send(token, "New Invoice", `Your rent invoice of ₹${amount} for ${data.period} is ready.`, { type: "invoice", hostelId });
});
//# sourceMappingURL=index.js.map