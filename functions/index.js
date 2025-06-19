/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// const {onRequest} = require("firebase-functions/v2/https");
// const logger = require("firebase-functions/logger");

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendChannelRequestNotification = functions.firestore
  .document('channel_requests/{requestId}')
  .onCreate(async (snapshot, context) => {
    const requestData = snapshot.data();
    
    const usersSnapshot = await admin.firestore().collection('users').get();
    const notifications = [];

    usersSnapshot.forEach(userDoc => {
      const userData = userDoc.data();

      notifications.push(
        admin.firestore().collection('users').doc(userDoc.id)
          .collection('notifications').add({
            title: `New Request in ${requestData.channelName}`,
            body: `${requestData.userName} is looking for: ${requestData.requestText.substring(0, 100)}...`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
            type: 'channel_request',
            channelId: requestData.channelId,
            requestId: context.params.requestId
          })
      );
    });

    return Promise.all(notifications);
  });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
