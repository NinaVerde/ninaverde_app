const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

const { defineSecret } = require("firebase-functions/params");
const fetch = require("node-fetch");

const OPENAI_KEY = defineSecret("OPENAI_API_KEY");
const BREVO_KEY = defineSecret("BREVO_API_KEY");
const TWILIO_SID = defineSecret("TWILIO_ACCOUNT_SID");
const TWILIO_TOKEN = defineSecret("TWILIO_AUTH_TOKEN");
const TWILIO_FROM = defineSecret("TWILIO_FROM");

const DEFAULT_MODEL = "gpt-4o-mini";

const buildSystemPrompt = (payload) => {
  const persona = payload.persona || {};
  const language = payload.language === "es" ? "Spanish" : "English";

  return [
    "You are Angelina, the Niña Verde AI hostess.",
    "Tone: warm, confident, lightly playful, classy, flirty, never explicit.",
    "You are bilingual and reply in the same language as the user.",
    `User language: ${language}.`,
    `Persona name: ${persona.name || "Angelina"}.`,
    `Persona (EN): ${persona.bioEn || ""}`,
    `Persona (ES): ${persona.bioEs || ""}`,
    "You are knowledgeable about Niña Verde, Granada, and Nicaragua.",
    "When relevant, return actions for ordering or checkout.",
    "Available actions: add_to_cart {productId, quantity}, remove_from_cart {productId, quantity}, go_to_checkout.",
    "Only use go_to_checkout when the user confirms. Otherwise set requiresConfirmation=true.",
    "Return JSON: { reply: string, actions: [], requiresConfirmation: boolean }.",
  ].join("\n");
};

const buildMenuContext = (menu = []) => {
  if (!Array.isArray(menu) || menu.length === 0) {
    return "Menu: unavailable.";
  }
  const items = menu.slice(0, 80).map((item) => {
    return `${item.name} (id: ${item.id}, category: ${item.category}, price: ${item.price})`;
  });
  return `Menu items:\n${items.join("\n")}`;
};

const buildKnowledgeContext = (knowledge = []) => {
  if (!Array.isArray(knowledge) || knowledge.length === 0) {
    return "Knowledge: none.";
  }
  const items = knowledge.slice(0, 50).map((k) => {
    return `${k.title}: ${k.contentEn || ""} ${k.contentEs || ""}`.trim();
  });
  return `Knowledge:\n${items.join("\n")}`;
};

const buildCartContext = (cart = []) => {
  if (!Array.isArray(cart) || cart.length === 0) {
    return "Cart: empty.";
  }
  const items = cart.map((item) => {
    return `${item.quantity}x ${item.name} (id: ${item.productId})`;
  });
  return `Cart:\n${items.join("\n")}`;
};

exports.angelinaChat = onRequest(
  { cors: true, region: "us-central1", secrets: [OPENAI_KEY] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    if (!OPENAI_KEY.value()) {
      res.status(500).json({ error: "Missing OPENAI_API_KEY" });
      return;
    }

    try {
      const payload = req.body || {};
      const userMessage = payload.message || "";
      const systemPrompt = buildSystemPrompt(payload);
      const menuContext = buildMenuContext(payload.menu);
      const knowledgeContext = buildKnowledgeContext(payload.knowledge);

      const cartContext = buildCartContext(payload.cart);
      const messages = [
        { role: "system", content: systemPrompt },
        { role: "system", content: menuContext },
        { role: "system", content: knowledgeContext },
        { role: "system", content: cartContext },
        { role: "user", content: userMessage },
      ];

      const openaiResp = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${OPENAI_KEY.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: DEFAULT_MODEL,
          messages,
          temperature: 0.6,
          max_tokens: 320,
          response_format: { type: "json_object" },
        }),
      });

      if (!openaiResp.ok) {
        const text = await openaiResp.text();
        res.status(500).json({ error: "OpenAI error", detail: text });
        return;
      }

      const data = await openaiResp.json();
      const content = data.choices?.[0]?.message?.content || "";
      const parsed = JSON.parse(content);

      res.json({
        reply: parsed.reply || "How can I help?",
        actions: Array.isArray(parsed.actions) ? parsed.actions : [],
        requiresConfirmation: parsed.requiresConfirmation === true,
      });
    } catch (err) {
      res.status(500).json({ error: "Angelina error", detail: `${err}` });
    }
  }
);

const _db = admin.firestore();

const loadRecipients = async (campaign) => {
  const channel = campaign.channel;
  const audience = campaign.audienceType;
  const listId = campaign.leadListId || "";
  const recipients = [];

  if (audience === "all_users") {
    const snap = await _db
      .collection("users")
      .where(`optIn${channel[0].toUpperCase()}${channel.slice(1)}`, "==", true)
      .get();
    snap.forEach((doc) => {
      const data = doc.data() || {};
      recipients.push({
        id: doc.id,
        type: "user",
        email: data.email,
        phone: data.phoneNumber,
      });
    });
  } else if (audience === "all_leads") {
    const snap = await _db
      .collection("leads")
      .where(`optIn${channel[0].toUpperCase()}${channel.slice(1)}`, "==", true)
      .get();
    snap.forEach((doc) => {
      const data = doc.data() || {};
      recipients.push({
        id: doc.id,
        type: "lead",
        email: data.email,
        phone: data.phone,
      });
    });
  } else if (audience === "lead_list" && listId) {
    const snap = await _db
      .collection("leads")
      .where("listIds", "array-contains", listId)
      .where(`optIn${channel[0].toUpperCase()}${channel.slice(1)}`, "==", true)
      .get();
    snap.forEach((doc) => {
      const data = doc.data() || {};
      recipients.push({
        id: doc.id,
        type: "lead",
        email: data.email,
        phone: data.phone,
      });
    });
  }

  return recipients;
};

const sendEmailBrevo = async ({ toEmail, subject, html, text }) => {
  if (!BREVO_KEY.value()) throw new Error("Missing BREVO_API_KEY");
  const resp = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": BREVO_KEY.value(),
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      sender: { name: "Niña Verde", email: "no-reply@ninaverde.app" },
      to: [{ email: toEmail }],
      subject,
      htmlContent: html,
      textContent: text,
    }),
  });
  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`Brevo error: ${detail}`);
  }
};

const sendSmsTwilio = async ({ toPhone, body }) => {
  if (!TWILIO_SID.value() || !TWILIO_TOKEN.value() || !TWILIO_FROM.value()) {
    throw new Error("Missing Twilio credentials");
  }
  const auth = Buffer.from(`${TWILIO_SID.value()}:${TWILIO_TOKEN.value()}`).toString("base64");
  const resp = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_SID.value()}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        To: toPhone,
        From: TWILIO_FROM.value(),
        Body: body,
      }),
    }
  );
  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`Twilio error: ${detail}`);
  }
};

const sendPush = async ({ tokens, title, body }) => {
  if (!tokens.length) return;
  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
  });
};

const buildUnsubLink = ({ type, recipientType, id }) => {
  const projectId = process.env.GCLOUD_PROJECT || "e-commerce-nina-verde-vy-451f6";
  return `https://us-central1-${projectId}.cloudfunctions.net/unsubscribe?type=${type}&recipientType=${recipientType}&id=${id}`;
};

const withUnsubFooter = ({ type, recipient }) => {
  const link = buildUnsubLink({
    type,
    recipientType: recipient.type,
    id: recipient.id,
  });
  const text = `\n\nOpt out: ${link}`;
  const html = `<br/><br/><small>Opt out: <a href="${link}">${link}</a></small>`;
  return { text, html };
};

exports.processCampaignQueue = onSchedule(
  { schedule: "every 5 minutes", region: "us-central1", secrets: [BREVO_KEY, TWILIO_SID, TWILIO_TOKEN, TWILIO_FROM] },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const snap = await _db
      .collection("campaigns")
      .where("status", "==", "scheduled")
      .where("scheduleAt", "<=", now)
      .limit(5)
      .get();

    for (const doc of snap.docs) {
      const campaign = doc.data();
      await doc.ref.set({ status: "sending", startedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

      const recipients = await loadRecipients(campaign);
      let sent = 0;
      let failed = 0;

      try {
        if (campaign.channel === "email") {
          for (const recipient of recipients) {
            if (!recipient.email) continue;
            try {
              const footer = withUnsubFooter({ type: "email", recipient });
              await sendEmailBrevo({
                toEmail: recipient.email,
                subject: campaign.subject || campaign.title || "Niña Verde",
                html: `${campaign.html || campaign.body || ""}${footer.html}`,
                text: `${campaign.body || ""}${footer.text}`,
              });
              sent += 1;
            } catch (_) {
              failed += 1;
            }
          }
        } else if (campaign.channel === "sms") {
          for (const recipient of recipients) {
            if (!recipient.phone) continue;
            try {
              const footer = withUnsubFooter({ type: "sms", recipient });
              await sendSmsTwilio({
                toPhone: recipient.phone,
                body: `${campaign.body || ""}${footer.text}`,
              });
              sent += 1;
            } catch (_) {
              failed += 1;
            }
          }
        } else if (campaign.channel === "push") {
          const tokenSnap = await _db
            .collection("push_tokens")
            .where("optInPush", "==", true)
            .get();
          const tokens = tokenSnap.docs.map((t) => t.data().token).filter(Boolean);
          await sendPush({
            tokens,
            title: campaign.title || "Niña Verde",
            body: campaign.body || "",
          });
          sent = tokens.length;
        }
      } finally {
        await doc.ref.set(
          {
            status: "sent",
            sentCount: sent,
            failCount: failed,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    }
  }
);

exports.unsubscribe = onRequest({ cors: true, region: "us-central1" }, async (req, res) => {
  try {
    const type = (req.query.type || "").toString();
    const recipientType = (req.query.recipientType || "").toString();
    const id = (req.query.id || "").toString();
    if (!type || !recipientType || !id) {
      res.status(400).send("Missing parameters.");
      return;
    }

    const field = type === "sms" ? "optInSms" : type === "push" ? "optInPush" : "optInEmail";
    if (recipientType === "lead") {
      await _db.collection("leads").doc(id).set({ [field]: false }, { merge: true });
    } else {
      await _db.collection("users").doc(id).set({ [field]: false }, { merge: true });
    }
    res.status(200).send("You are unsubscribed.");
  } catch (err) {
    res.status(500).send("Unsubscribe failed.");
  }
});
