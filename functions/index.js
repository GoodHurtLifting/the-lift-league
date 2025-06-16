const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const OpenAI = require('openai');
const openai = new OpenAI({
  apiKey: functions.config().openai.key,
});

exports.notifyNewMessage = onDocumentCreated(
  'chats/{chatId}/messages/{messageId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const message = snap.data();
    const chatId = event.params.chatId;
    const senderId = message.senderId;

    // Get parent chat doc to find all members
    const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return;

    const members = chatDoc.data().members || [];
    const recipients = members.filter(uid => uid !== senderId);

    if (recipients.length === 0) return;
    const userDocs = await admin.firestore().collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', recipients)
      .get();

    const tokens = [];
    userDocs.forEach(doc => {
      const data = doc.data();
      const prefs = (data.notificationPrefs || {});
      const shouldNotify = (typeof prefs.messages !== "undefined") ? prefs.messages : true;
      if (!shouldNotify) return;
      const token = data.fcmToken;
      if (
        typeof token === "string" &&
        token.length > 10 &&
        token !== "null" &&
        token !== "undefined" &&
        !token.includes("null") &&
        !token.includes("undefined")
      ) {
        tokens.push(token);
      }
    });
    console.log('Sending notification to tokens:', tokens);
    if (tokens.length === 0) {
      console.log('No valid FCM tokens, aborting notification send.');
      return;
    }

    const payload = {
      notification: {
        title: "New Message",
        body: message.text ? message.text.substring(0, 60) : "You've got a message!",
      },
      data: {
        chatId: chatId,
        messageId: event.params.messageId,
      }
    };
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: payload.notification,
      data: payload.data,
    });
    console.log(`DM notification sent to ${tokens.length} devices.`);
  }
);

exports.notifyTrainingCircle = onDocumentCreated(
  'users/{userId}/timeline_entries/{entryId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const entry = snap.data();
    const userId = event.params.userId;

    // 1. Get all members from this user's training_circle subcollection
    const circleSnap = await admin.firestore()
      .collection('users').doc(userId)
      .collection('training_circle').get();

    const memberIds = [];
    circleSnap.forEach(doc => {
      memberIds.push(doc.id);
    });

    // 2. Remove self (the user who triggered the event)
    const notifyIds = memberIds.filter(id => id !== userId);

    // 3. Fetch FCM tokens for all members (if trainingCircle enabled)
    const userDocs = await admin.firestore()
      .collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', notifyIds)
      .get();

    const tokens = [];
    userDocs.forEach(doc => {
      const data = doc.data();
      const prefs = (data.notificationPrefs || {});
      const shouldNotify = (typeof prefs.trainingCircle !== "undefined") ? prefs.trainingCircle : true;
      if (!shouldNotify) return;
      const token = data.fcmToken;
      if (
        typeof token === "string" &&
        token.length > 10 &&
        token !== "null" &&
        token !== "undefined" &&
        !token.includes("null") &&
        !token.includes("undefined")
      ) {
        tokens.push(token);
      }
    });
    console.log('Sending notification to tokens:', tokens);
    if (tokens.length === 0) {
      console.log('No valid FCM tokens, aborting notification send.');
      return;
    }

    const payload = {
      notification: {
        title: "Training Circle Update!",
        body: `${entry.type === 'clink' ? "Clink" : "Check-in"} posted in your circle.`,
      },
      data: {
        userId,
        entryId: event.params.entryId,
      }
    };

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: payload.notification,
      data: payload.data,
    });
    console.log(`DM notification sent to ${tokens.length} devices.`);
  }
);

exports.evaluateTrainingBlock = functions.https.onCall(async (data, context) => {
  try {
    const blockData = data.block;

    const prompt = `
You are a strength training coach reviewing a users custom training block. Evaluate the overall structure, balance, and effectiveness of the block using the following data:

${JSON.stringify(blockData, null, 2)}

Provide 2–3 specific points of feedback. Be encouraging but honest. Sound like a knowledgeable gym coach.
    `.trim();

    const response = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [{ role: "user", content: prompt }],
    });
    const feedback = response.choices[0].message.content;
    return { feedback };

  } catch (error) {
    console.error("AI feedback error:", error);
    throw new functions.https.HttpsError('internal', 'Failed to generate feedback.');
  }
});
