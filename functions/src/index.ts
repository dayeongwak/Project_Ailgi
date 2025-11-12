// functions/src/index.ts (DM 알림도 'notifications' 컬렉션에 저장)

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const fcm = admin.messaging();

// settings_page.dart와 동일한 키 정의
const KEY_ALL_NOTIFY_ENABLED = "_all_notify_enabled";
const KEY_FRIEND_REQUEST_NOTIFY_ENABLED = "_friend_request_notify_enabled";
const KEY_LIKE_NOTIFY_ENABLED = "_like_notify_enabled";
const KEY_COMMENT_NOTIFY_ENABLED = "_comment_notify_enabled";
// (DM 알림 키는 아직 settings_page에 없으므로, '전체 알림'만 따름)
const KEY_DM_NOTIFY_ENABLED = "_dm_notify_enabled"; // (새 키, 나중에 앱에 추가)


/**
 * (헬퍼 함수)
 * 알림을 받을 사용자의 UID로 FCM 토큰과 푸시 알림 설정을 가져옵니다.
 */
async function getRecipientInfo(uid: string): Promise<{
  token?: string;
  settings: {
    allEnabled: boolean;
    friendRequest: boolean;
    like: boolean;
    comment: boolean;
    dm: boolean;
  };
}> {
  const info = {
    settings: {
      allEnabled: true,
      friendRequest: true,
      like: true,
      comment: true,
      dm: true,
    },
    token: undefined as string | undefined,
  };

  try {
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
      console.log(`[FCM] User doc ${uid} not found.`);
      return info;
    }
    const userData = userDoc.data();
    if (!userData) {
      console.log(`[FCM] User data for ${uid} is empty.`);
      return info;
    }

    info.token = userData.fcmToken;

    // Firestore에 저장된 알림 설정 읽기
    info.settings.allEnabled = userData[KEY_ALL_NOTIFY_ENABLED] ?? true;
    info.settings.friendRequest =
      userData[KEY_FRIEND_REQUEST_NOTIFY_ENABLED] ?? true;
    info.settings.like = userData[KEY_LIKE_NOTIFY_ENABLED] ?? true;
    info.settings.comment = userData[KEY_COMMENT_NOTIFY_ENABLED] ?? true;
    info.settings.dm = userData[KEY_DM_NOTIFY_ENABLED] ?? true; // (DM 설정 읽기)

    return info;
  } catch (e) {
    console.error(`[FCM] Error getting recipient info for ${uid}:`, e);
    return info;
  }
}

/**
 * [FCM 트리거 1, 2, 3] '공감', '댓글', '친구 요청' 알림
 * (이 함수는 수정할 필요 없음 - 이미 잘 작동)
 */
export const onNewNotification = functions
  .region("asia-northeast3")
  .firestore.document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snapshot: functions.firestore.DocumentSnapshot, context: functions.EventContext) => {
    const { userId } = context.params;
    const data = snapshot.data();

    if (!data) return console.log("[FCM] No data in notification snapshot.");

    // ✅ [수정] DM 알림은 onNewDM에서 별도 처리하므로 여기서 제외
    const type = data.type;
    if (type === "dm") {
      return console.log("[FCM] DM notification detected, skipping onNewNotification trigger.");
    }

    const fromNickname = data.fromNickname;
    const fromUid = data.fromUid;

    if (fromUid === userId) return console.log("[FCM] Sender is same as recipient. Skipped.");

    const recipient = await getRecipientInfo(userId);
    if (!recipient.token) return console.log(`[FCM] No FCM token for user ${userId}.`);

    let title = "";
    let body = "";
    let shouldSend = recipient.settings.allEnabled;

    if (type === "like") {
      title = `${fromNickname} 님이 회원님의 글에 공감했습니다 ❤️`;
      body = `일기 요약: ${data.summary || ""}`;
      shouldSend = shouldSend && recipient.settings.like;
    } else if (type === "comment") {
      title = `${fromNickname} 님이 회원님의 글에 댓글을 남겼습니다 💬`;
      body = data.commentText || "";
      shouldSend = shouldSend && recipient.settings.comment;
    } else if (type === "friend_request") {
      title = "새로운 친구 요청이 도착했어요! 🤝";
      body = `${fromNickname} 님이 친구 요청을 보냈습니다.`;
      shouldSend = shouldSend && recipient.settings.friendRequest;
    } else {
      return console.log(`[FCM] Unknown notification type: ${type}`);
    }

    if (!shouldSend) {
      return console.log(`[FCM] User ${userId} has disabled '${type}' notifications.`);
    }

    const payload: admin.messaging.MessagingPayload = {
      notification: { title: title, body: body, badge: "1" },
      data: { type: type, diaryDateKey: data.diaryDateKey || "", fromUid: fromUid },
    };

    console.log(`[FCM] Sending '${type}' notification to ${userId}`);
    return fcm.sendToDevice(recipient.token, payload);
  });

/**
 * [FCM 트리거 4] '1:1 DM' 알림
 * (DM이 오면 '인앱 알림'을 생성하고 '푸시 알림'도 보냄)
 */
export const onNewDM = functions
  .region("asia-northeast3")
  .firestore.document("chats/{chatRoomId}/messages/{messageId}")
  .onCreate(async (snapshot: functions.firestore.DocumentSnapshot, context: functions.EventContext) => {
    const data = snapshot.data();
    if (!data) return console.log("[FCM-DM] No data in message snapshot.");

    const senderId = data.author?.id;
    if (!senderId) return console.log("[FCM-DM] Sender ID missing.");

    const chatRoomDoc = await db.collection("chats").doc(context.params.chatRoomId).get();
    const chatRoomData = chatRoomDoc.data();
    const participants = chatRoomData?.participants as string[];

    if (!participants || participants.length !== 2) return console.log("[FCM-DM] Invalid participants data.");

    const recipientId = participants.find((uid) => uid !== senderId);
    if (!recipientId) return console.log("[FCM-DM] Recipient ID not found.");

    const recipient = await getRecipientInfo(recipientId);
    const senderNickname = chatRoomData?.participantInfo?.[senderId]?.nickname ?? "친구";
    const messageText = data.text || (data.uri ? "📷 사진" : "메시지");

    // ▼▼▼▼▼ [신규] 1:1 DM도 /users/{userId}/notifications 에 기록 ▼▼▼▼▼
    try {
      const notificationRef = db.collection("users").doc(recipientId).collection("notifications").doc();
      await notificationRef.set({
        type: "dm",
        fromUid: senderId,
        fromNickname: senderNickname,
        dmText: messageText,
        chatRoomId: context.params.chatRoomId, // DM 방 ID
        timestamp: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });
      console.log(`[FCM-DM] In-app notification created for ${recipientId}.`);
    } catch (e) {
      console.error("[FCM-DM] Error creating in-app notification:", e);
    }
    // ▲▲▲▲▲ [신규] 1:1 DM도 /users/{userId}/notifications 에 기록 ▲▲▲▲▲

    // 2. 사용자가 DM 푸시 알림을 껐다면 전송 중지
    if (!recipient.settings.allEnabled || !recipient.settings.dm) {
      return console.log(`[FCM-DM] User ${recipientId} has disabled DM push notifications.`);
    }

    if (!recipient.token) return console.log(`[FCM-DM] No FCM token for user ${recipientId}.`);

    // 3. 푸시 알림 페이로드 구성
    const payload: admin.messaging.MessagingPayload = {
      notification: {
        title: senderNickname,
        body: messageText,
        badge: "1",
      },
      data: {
        type: "dm",
        chatRoomId: context.params.chatRoomId,
        fromUid: senderId,
        fromNickname: senderNickname,
      },
    };

    console.log(`[FCM-DM] Sending DM push notification to ${recipientId}`);
    return fcm.sendToDevice(recipient.token, payload);
  });