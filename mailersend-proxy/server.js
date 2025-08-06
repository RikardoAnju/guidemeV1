import express from "express";
import axios from "axios";
import cors from "cors";
import crypto from "crypto";
import admin from "firebase-admin";
import { config } from "dotenv";

config();

const app = express();

// ================================

// MIDDLEWARE CONFIGURATION
// ================================

// CORS configuration
app.use(cors({
  origin: "*",
  credentials: true,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "ngrok-skip-browser-warning", "X-Requested-With", "User-Agent"],
}));

app.options("*", cors());

// Global middleware
app.use((req, res, next) => {
  res.setHeader("Content-Type", "application/json");
  next();
});

app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Request logging middleware
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path} - ${new Date().toISOString()}`);
  next();
});

// ================================
// FIREBASE INITIALIZATION
// ================================

let db = null;
let firebaseEnabled = false;

const initializeFirebase = () => {
  try {
    if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PRIVATE_KEY) {
      admin.initializeApp({
        credential: admin.credential.cert({
          type: "service_account",
          project_id: process.env.FIREBASE_PROJECT_ID,
          private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
          private_key: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
          client_email: process.env.FIREBASE_CLIENT_EMAIL,
          client_id: process.env.FIREBASE_CLIENT_ID,
          auth_uri: "https://accounts.google.com/o/oauth2/auth",
          token_uri: "https://oauth2.googleapis.com/token",
          auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
          client_x509_cert_url: `https://www.googleapis.com/robot/v1/metadata/x509/${process.env.FIREBASE_CLIENT_EMAIL}`,
        }),
      });
      db = admin.firestore();
      firebaseEnabled = true;
      console.log("✅ Firebase initialized");
    }
  } catch (error) {
    console.warn("⚠️ Firebase init failed:", error.message);
  }
};

initializeFirebase();

// ================================
// CONFIGURATION CHECKS
// ================================

const emailConfigOK = !!process.env.MAILERSEND_API_KEY;
const midtransConfigOK = !!process.env.MIDTRANS_SERVER_KEY;

// ================================
// UTILITY FUNCTIONS
// ================================

const mapTransactionStatus = (status) => {
  const statusMap = {
    settlement: { status: "success", isPaid: true },
    capture: { status: "success", isPaid: true },
    pending: { status: "pending", isPaid: false },
    cancel: { status: "cancelled", isPaid: false },
    expire: { status: "expired", isPaid: false },
    deny: { status: "failed", isPaid: false },
    failure: { status: "failed", isPaid: false },
  };
  return statusMap[status] || { status: "unknown", isPaid: false };
};

const updateFirebasePaymentStatus = async (orderId, statusInfo, transactionStatus, transactionData = null) => {
  if (!firebaseEnabled) {
    console.log("⚠️ Firebase not enabled, skipping update");
    return { success: false, message: "Firebase not enabled" };
  }

  try {
    const docRef = db.collection("payments").doc(orderId);
    const doc = await docRef.get();

    if (!doc.exists) {
      console.log(`⚠️ Order ${orderId} not found in Firebase - payment record must be created by frontend first`);
      return { 
        success: false, 
        message: "Payment record not found - must be created by frontend first" 
      };
    }

    // Prepare update data
    const updateData = {
      status: statusInfo.status,
      is_paid: statusInfo.isPaid,
      transaction_status: transactionStatus,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Add additional transaction data if provided
    if (transactionData) {
      updateData.payment_type = transactionData.payment_type || null;
      updateData.transaction_time = transactionData.transaction_time || null;
      updateData.gross_amount = transactionData.gross_amount || null;
      updateData.fraud_status = transactionData.fraud_status || null;
      updateData.currency = transactionData.currency || null;
    }

    await docRef.update(updateData);
    
    console.log(`✅ Firebase payment status updated for order ${orderId}: ${statusInfo.status}`);
    
    return { 
      success: true, 
      message: "Payment status updated successfully",
      status: statusInfo.status,
      is_paid: statusInfo.isPaid
    };
  } catch (error) {
    console.error(`❌ Firebase update error for order ${orderId}:`, error);
    return { 
      success: false, 
      message: "Failed to update Firebase",
      error: error.message 
    };
  }
};

const sendEmail = async (emailData) => {
  if (!emailConfigOK) {
    throw new Error("Email service not configured - missing MAILERSEND_API_KEY");
  }

  try {
    const response = await axios.post(
      "https://api.mailersend.com/v1/email",
      emailData,
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${process.env.MAILERSEND_API_KEY}`,
        },
        timeout: 30000,
      }
    );
    return response.data;
  } catch (error) {
    console.error("❌ Email send error:", error.response?.data || error.message);
    throw error;
  }
};

const verifyMidtransSignature = (orderId, statusCode, grossAmount, signatureKey) => {
  const serverKey = process.env.MIDTRANS_SERVER_KEY;
  const expectedSignature = crypto
    .createHash("sha512")
    .update(orderId + statusCode + grossAmount + serverKey)
    .digest("hex");
  
  return signatureKey === expectedSignature;
};

const validateRequiredFields = (fields, data) => {
  const missingFields = fields.filter(field => !data[field]);
  if (missingFields.length > 0) {
    throw new Error(`Missing required fields: ${missingFields.join(", ")}`);
  }
};

// ================================
// ROUTE HANDLERS
// ================================

// Health check and info routes
app.get("/", (req, res) => {
  res.json({
    message: "Payment Backend Server",
    status: "RUNNING",
    firebase_enabled: firebaseEnabled,
    email_config_ok: emailConfigOK,
    midtrans_config_ok: midtransConfigOK,
    note: "Payment records are created by frontend, backend only updates status",
    endpoints: [
      "POST /send-otp",
      "POST /reset-password",
      "POST /generate-snap-token",
      "POST /midtrans-webhook",
      "GET /payment-finish",
      "GET /payment-status/:orderId",
      "POST /payment-status",
      "GET /health",
    ],
  });
});

app.get("/health", (req, res) => {
  res.json({
    status: "OK",
    firebase_enabled: firebaseEnabled,
    email_config_ok: emailConfigOK,
    midtrans_config_ok: midtransConfigOK,
    timestamp: new Date().toISOString(),
  });
});

// Email routes
app.post("/send-otp", async (req, res) => {
  try {
    const { from, to, subject, text, html } = req.body;
    
    validateRequiredFields(["from", "to", "subject"], req.body);
    
    if (!text && !html) {
      return res.status(400).json({
        success: false,
        message: "Either text or html content is required",
      });
    }

    const emailPayload = {
      from: { email: from },
      to: [{ email: to }],
      subject,
      ...(html && { html }),
      ...(text && { text }),
    };

    await sendEmail(emailPayload);

    res.json({
      success: true,
      message: "OTP email sent successfully",
      recipient: to,
    });
  } catch (error) {
    console.error("❌ Send OTP error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to send OTP email",
      error: error.message,
    });
  }
});

// Authentication routes
app.post("/reset-password", async (req, res) => {
  try {
    const { email, newPassword } = req.body;
    
    validateRequiredFields(["email", "newPassword"], req.body);

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: "Invalid email format",
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters long",
      });
    }

    if (!firebaseEnabled) {
      return res.status(500).json({
        success: false,
        message: "Firebase not configured",
      });
    }

    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(user.uid, { password: newPassword });

    res.json({
      success: true,
      message: "Password updated successfully",
      email: email,
    });
  } catch (error) {
    console.error("❌ Reset password error:", error);
    
    const errorMessages = {
      'auth/user-not-found': 'User not found',
      'auth/invalid-email': 'Invalid email format',
      'auth/weak-password': 'Password is too weak',
    };

    const statusCode = error.code === 'auth/user-not-found' ? 404 : 400;
    res.status(statusCode).json({
      success: false,
      message: errorMessages[error.code] || "Reset password failed",
      error_code: error.code,
    });
  }
});

// Payment routes
app.post("/generate-snap-token", async (req, res) => {
  try {
    const { order_id, gross_amount, customer_details, item_details } = req.body;
    
    validateRequiredFields(["order_id", "gross_amount", "customer_details", "item_details"], req.body);

    if (!midtransConfigOK) {
      return res.status(500).json({
        success: false,
        message: "Midtrans not configured - missing MIDTRANS_SERVER_KEY",
      });
    }

    const serverKey = process.env.MIDTRANS_SERVER_KEY;
    const encodedKey = Buffer.from(serverKey + ":").toString("base64");

    const transactionData = {
      transaction_details: { order_id, gross_amount },
      customer_details: {
        first_name: customer_details.first_name || "Customer",
        email: customer_details.email || "",
        phone: customer_details.phone || "",
      },
      item_details: item_details.map((item) => ({
        id: item.id,
        price: item.price,
        quantity: item.quantity,
        name: item.name,
      })),
      credit_card: { secure: true }

    };

    const response = await axios.post(
      "https://app.sandbox.midtrans.com/snap/v1/transactions",
      transactionData,
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Basic ${encodedKey}`,
        },
        timeout: 30000,
      }
    );

    console.log(`✅ Payment token generated for order: ${order_id}`);
    console.log(`📝 Note: Payment record should be created by frontend before token generation`);

    res.json({
      success: true,
      snap_token: response.data.token,
      order_id,
      message: "Payment token generated successfully",
      note: "Ensure payment record is created in Firebase by frontend",
    });
  } catch (error) {
    console.error("❌ Payment token error:", error.response?.data || error.message);
    res.status(500).json({
      success: false,
      message: "Failed to generate payment token",
      error: error.response?.data || error.message,
    });
  }
});

app.post("/midtrans-webhook", async (req, res) => {
  try {
    const { order_id, status_code, gross_amount, signature_key, transaction_status, payment_type, transaction_time, fraud_status, currency } = req.body;
    
    validateRequiredFields(["order_id", "signature_key", "transaction_status"], req.body);

    if (!midtransConfigOK) {
      return res.status(500).json({
        success: false,
        message: "Midtrans not configured",
      });
    }

    // Verify signature
    if (!verifyMidtransSignature(order_id, status_code, gross_amount, signature_key)) {
      return res.status(400).json({
        success: false,
        message: "Invalid signature",
      });
    }

    const statusInfo = mapTransactionStatus(transaction_status);
    
    // Prepare additional transaction data
    const transactionData = {
      payment_type,
      transaction_time,
      gross_amount,
      fraud_status,
      currency
    };

    const updateResult = await updateFirebasePaymentStatus(order_id, statusInfo, transaction_status, transactionData);

    if (statusInfo.status === "success") {
      console.log(`🎉 Payment SUCCESS for order ${order_id} - Firebase updated automatically`);
    }

    res.json({
      success: true,
      message: "Webhook processed successfully",
      order_id,
      status: statusInfo.status,
      is_paid: statusInfo.isPaid,
      firebase_update: updateResult,
    });
  } catch (error) {
    console.error("❌ Webhook processing error:", error);
    res.status(500).json({
      success: false,
      message: "Webhook processing failed",
      error: error.message,
    });
  }
});

app.get("/payment-finish", async (req, res) => {
  try {
    const { order_id, transaction_status } = req.query;

    if (!order_id) {
      return res.status(400).json({
        success: false,
        message: "Order ID is required",
      });
    }

    const statusInfo = mapTransactionStatus(transaction_status);
    const updateResult = await updateFirebasePaymentStatus(order_id, statusInfo, transaction_status);

    const messages = {
      success: "Payment completed successfully",
      pending: "Payment is still pending",
      cancelled: "Payment was cancelled",
      expired: "Payment has expired",
      failed: "Payment failed",
    };

    res.json({
      success: statusInfo.isPaid,
      message: messages[statusInfo.status] || "Payment status unknown",
      order_id,
      status: statusInfo.status,
      is_paid: statusInfo.isPaid,
      firebase_update: updateResult,
    });
  } catch (error) {
    console.error("❌ Payment finish error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: error.message,
    });
  }
});

// Unified payment status handler
const handlePaymentStatus = async (req, res) => {
  try {
    const orderId = req.params.orderId || req.body.order_id;

    if (!orderId) {
      return res.status(400).json({
        success: false,
        message: "Order ID is required",
      });
    }

    if (!midtransConfigOK) {
      return res.status(500).json({
        success: false,
        message: "Midtrans not configured",
      });
    }

    const serverKey = process.env.MIDTRANS_SERVER_KEY;
    const encodedKey = Buffer.from(serverKey + ":").toString("base64");

    // Get status from Midtrans
    const response = await axios.get(
      `https://api.sandbox.midtrans.com/v2/${orderId}/status`,
      {
        headers: {
          Authorization: `Basic ${encodedKey}`,
          "Content-Type": "application/json",
        },
        timeout: 10000,
      }
    );

    const statusInfo = mapTransactionStatus(response.data.transaction_status);
    
    // Update Firebase with latest status
    const transactionData = {
      payment_type: response.data.payment_type,
      transaction_time: response.data.transaction_time,
      gross_amount: response.data.gross_amount,
      fraud_status: response.data.fraud_status,
      currency: response.data.currency
    };

    const updateResult = await updateFirebasePaymentStatus(orderId, statusInfo, response.data.transaction_status, transactionData);

    // Get current Firebase data
    let firebaseData = null;
    if (firebaseEnabled) {
      try {
        const doc = await db.collection("payments").doc(orderId).get();
        if (doc.exists) {
          firebaseData = doc.data();
        }
      } catch (error) {
        console.error("❌ Firebase read error:", error);
      }
    }

    res.json({
      success: true,
      order_id: orderId,
      status: statusInfo.status,
      is_paid: statusInfo.isPaid,
      transaction_status: response.data.transaction_status,
      payment_type: response.data.payment_type,
      transaction_time: response.data.transaction_time,
      gross_amount: response.data.gross_amount,
      firebase_update: updateResult,
      firebase_data: firebaseData,
    });
  } catch (error) {
    console.error("❌ Payment status error:", error);
    
    if (error.response?.status === 404) {
      return res.status(404).json({
        success: false,
        message: "Order not found in Midtrans",
        order_id: req.params.orderId || req.body.order_id,
      });
    }

    res.status(500).json({
      success: false,
      message: "Failed to check payment status",
      error: error.message,
    });
  }
};

// Payment status routes
app.get("/payment-status/:orderId", handlePaymentStatus);
app.post("/payment-status", handlePaymentStatus);

// ================================
// ERROR HANDLING
// ================================

// Global error handler
const handleError = (error, req, res, next) => {
  console.error("❌ Unhandled Error:", error);
  if (!res.headersSent) {
    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: error.message,
    });
  }
};

app.use(handleError);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
    path: req.path,
    method: req.method,
    available_endpoints: [
      "GET /",
      "GET /health",
      "POST /send-otp",
      "POST /reset-password",
      "POST /generate-snap-token",
      "POST /midtrans-webhook",
      "GET /payment-finish",
      "GET /payment-status/:orderId",
      "POST /payment-status",
    ],
  });
});

// ================================
// SERVER STARTUP
// ================================

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`\n🚀 Payment Backend Server Started`);
  console.log(`📡 Port: ${PORT}`);
  console.log(`🔥 Firebase: ${firebaseEnabled ? "✅ Enabled" : "❌ Disabled"}`);
  console.log(`📧 Email: ${emailConfigOK ? "✅ Configured" : "❌ Not configured"}`);
  console.log(`💳 Midtrans: ${midtransConfigOK ? "✅ Configured" : "❌ Not configured"}`);
  console.log(`🌐 Environment: ${process.env.NODE_ENV || "development"}`);
  console.log(`\n📝 IMPORTANT: Payment records are created by frontend, backend only updates status`);
  console.log(`\n📋 Available endpoints:`);
  console.log(`   GET    /`);
  console.log(`   GET    /health`);
  console.log(`   POST   /send-otp`);
  console.log(`   POST   /reset-password`);
  console.log(`   POST   /generate-snap-token`);
  console.log(`   POST   /midtrans-webhook`);
  console.log(`   GET    /payment-finish`);
  console.log(`   GET    /payment-status/:orderId`);
  console.log(`   POST   /payment-status`);
  console.log(`\n✅ Server ready to accept connections\n`);
});