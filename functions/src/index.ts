import * as admin from "firebase-admin";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ---------- Helpers ----------

async function getOwnerToken(hostelId: string): Promise<string | null> {
  const hostelSnap = await db.collection("hostels").doc(hostelId).get();
  const ownerId = hostelSnap.data()?.ownerId as string | undefined;
  if (!ownerId) return null;
  const userSnap = await db.collection("users").doc(ownerId).get();
  return (userSnap.data()?.fcmToken as string | undefined) ?? null;
}

async function getTenantToken(
  hostelId: string,
  guestId: string
): Promise<string | null> {
  const guestSnap = await db
    .collection("hostels")
    .doc(hostelId)
    .collection("guests")
    .doc(guestId)
    .get();
  const linkedUserId = guestSnap.data()?.linkedUserId as string | undefined;
  if (!linkedUserId) return null;
  const userSnap = await db.collection("users").doc(linkedUserId).get();
  return (userSnap.data()?.fcmToken as string | undefined) ?? null;
}

async function getAllTenantTokens(hostelId: string): Promise<string[]> {
  const guestsSnap = await db
    .collection("hostels")
    .doc(hostelId)
    .collection("guests")
    .where("isActive", "==", true)
    .where("linkedUserId", "!=", null)
    .get();

  const tokens: string[] = [];
  for (const guestDoc of guestsSnap.docs) {
    const linkedUserId = guestDoc.data().linkedUserId as string;
    const userSnap = await db.collection("users").doc(linkedUserId).get();
    const token = userSnap.data()?.fcmToken as string | undefined;
    if (token) tokens.push(token);
  }
  return tokens;
}

async function send(
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  try {
    await messaging.send({
      token,
      notification: {title, body},
      data,
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (err) {
    console.error("FCM send failed:", err);
  }
}

async function sendToMany(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  if (tokens.length === 0) return;
  try {
    await messaging.sendEachForMulticast({
      tokens,
      notification: {title, body},
      data,
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (err) {
    console.error("FCM multicast failed:", err);
  }
}

// ---------- Triggers ----------

// 1. New complaint → notify owner
export const onComplaintCreated = onDocumentCreated(
  "hostels/{hostelId}/complaints/{complaintId}",
  async (event) => {
    const hostelId = event.params.hostelId;
    const data = event.data?.data();
    if (!data) return;

    const token = await getOwnerToken(hostelId);
    if (!token) return;

    await send(
      token,
      "New Complaint",
      `${data.guestName} (Room ${data.roomNumber}): ${data.category}`,
      {type: "complaint", hostelId}
    );
  }
);

// 2. Complaint resolved → notify tenant
export const onComplaintUpdated = onDocumentUpdated(
  "hostels/{hostelId}/complaints/{complaintId}",
  async (event) => {
    const hostelId = event.params.hostelId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;

    if (after.status === "resolved") {
      const token = await getTenantToken(hostelId, after.guestId as string);
      if (!token) return;
      await send(
        token,
        "Complaint Resolved",
        `Your ${after.category} complaint has been resolved.`,
        {type: "complaint_resolved", hostelId}
      );
    }
  }
);

// 3. New notice → notify all active tenants
export const onNoticeCreated = onDocumentCreated(
  "hostels/{hostelId}/notices/{noticeId}",
  async (event) => {
    const hostelId = event.params.hostelId;
    const data = event.data?.data();
    if (!data) return;

    const tokens = await getAllTenantTokens(hostelId);
    await sendToMany(tokens, data.title as string, data.body as string, {
      type: "notice",
      hostelId,
    });
  }
);

// 4. Checkout request submitted → notify owner
export const onCheckoutRequestCreated = onDocumentCreated(
  "hostels/{hostelId}/checkout_requests/{requestId}",
  async (event) => {
    const hostelId = event.params.hostelId;
    const data = event.data?.data();
    if (!data) return;

    const token = await getOwnerToken(hostelId);
    if (!token) return;

    await send(
      token,
      "Checkout Request",
      `${data.guestName} (Room ${data.roomNumber}) wants to check out.`,
      {type: "checkout_request", hostelId}
    );
  }
);

// 5. Checkout approved/denied → notify tenant
export const onCheckoutRequestUpdated = onDocumentUpdated(
  "hostels/{hostelId}/checkout_requests/{requestId}",
  async (event) => {
    const hostelId = event.params.hostelId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;

    if (after.status === "approved" || after.status === "denied") {
      const token = await getTenantToken(hostelId, after.guestId as string);
      if (!token) return;

      const approved = after.status === "approved";
      await send(
        token,
        approved ? "Checkout Approved" : "Checkout Denied",
        approved
          ? "Your checkout request has been approved."
          : "Your checkout request was denied. Please contact the owner.",
        {type: "checkout_updated", hostelId, status: after.status as string}
      );
    }
  }
);

// 6. New invoice generated → notify tenant
export const onInvoiceCreated = onDocumentCreated(
  "hostels/{hostelId}/invoices/{invoiceId}",
  async (event) => {
    const hostelId = event.params.hostelId;
    const data = event.data?.data();
    if (!data) return;

    const token = await getTenantToken(hostelId, data.guestId as string);
    if (!token) return;

    const amount = data.gstEnabled ? data.totalWithGst : data.amount;
    await send(
      token,
      "New Invoice",
      `Your rent invoice of ₹${amount} for ${data.period} is ready.`,
      {type: "invoice", hostelId}
    );
  }
);
