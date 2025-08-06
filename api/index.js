import axios from "axios";
import crypto from "crypto";
import admin from "firebase-admin";

// Initialize Firebase
let db = null;
let firebaseEnabled = false;

function initFirebase() {
  if (!admin.apps.length) {
    try {
      // Check if all required Firebase environment variables are present
      const requiredEnvVars = [
        'FIREBASE_PROJECT_ID',
        'FIREBASE_PRIVATE_KEY',
        'FIREBASE_CLIENT_EMAIL'
      ];
      
      const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
      
      if (missingVars.length > 0) {
        console.warn(`⚠️ Missing Firebase environment variables: ${missingVars.join(', ')}`);
        firebaseEnabled = false;
        return;
      }

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
      console.log("✅ Firebase initialized successfully");
    } catch (error) {
      console.warn("⚠️ Firebase initialization failed:", error.message);
      firebaseEnabled = false;
    }
  } else {
    db = admin.firestore();
    firebaseEnabled = true;
  }
}

// Status mapping function
function mapTransactionStatus(midtransStatus) {
  const statusMapping = {
    'settlement': { status: 'success', isPaid: true, canNavigateHome: true },
    'capture': { status: 'success', isPaid: true, canNavigateHome: true },
    'pending': { status: 'pending', isPaid: false, canNavigateHome: false },
    'cancel': { status: 'cancelled', isPaid: false, canNavigateHome: false },
    'expire': { status: 'expired', isPaid: false, canNavigateHome: false },
    'deny': { status: 'failed', isPaid: false, canNavigateHome: false },
    'failure': { status: 'failed', isPaid: false, canNavigateHome: false },
    'default': { status: 'unknown', isPaid: false, canNavigateHome: false }
  };
  return statusMapping[midtransStatus] || statusMapping['default'];
}

// Check Midtrans status with better error handling
async function checkMidtransStatus(orderId) {
  try {
    const serverKey = process.env.MIDTRANS_SERVER_KEY;
    if (!serverKey) {
      throw new Error("MIDTRANS_SERVER_KEY environment variable is not set");
    }

    const encodedKey = Buffer.from(serverKey + ":").toString("base64");
    
    // Use production URL if not in sandbox mode
    const baseUrl = process.env.MIDTRANS_IS_PRODUCTION === 'true' 
      ? 'https://api.midtrans.com' 
      : 'https://api.sandbox.midtrans.com';
    
    const response = await axios.get(
      `${baseUrl}/v2/${orderId}/status`,
      {
        headers: {
          Authorization: `Basic ${encodedKey}`,
          "Content-Type": "application/json",
        },
        timeout: 15000, // 15 second timeout
      }
    );
    
    return response.data;
  } catch (error) {
    console.error("Error checking Midtrans status:", error.response?.data || error.message);
    throw error;
  }
}

// CORS headers with proper origin handling
function setCorsHeaders(req, res) {
  const origin = req.headers.origin;
  const allowedOrigins = process.env.ALLOWED_ORIGINS 
    ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
    : ['*'];
  
  // Check if origin is allowed
  if (allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin || '*');
  }
  
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Max-Age', '86400');
}

// Validate required environment variables
function validateEnvironment() {
  const requiredVars = ['MIDTRANS_SERVER_KEY'];
  const missingVars = requiredVars.filter(varName => !process.env[varName]);
  
  if (missingVars.length > 0) {
    throw new Error(`Missing required environment variables: ${missingVars.join(', ')}`);
  }
}

// Input validation helpers
function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function validateOrderId(orderId) {
  // Allow alphanumeric, hyphens, underscores, and dots
  return /^[a-zA-Z0-9_.-]+$/.test(orderId);
}

function sanitizeInput(input) {
  if (typeof input !== 'string') return input;
  return input.trim();
}

// Enhanced error handler
function handleError(error, res, context = '') {
  console.error(`❌ Error in ${context}:`, error);
  
  // Check if it's a known error type
  if (error.response?.status === 404) {
    return res.status(404).json({
      success: false,
      message: "Resource not found",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
  
  if (error.response?.status === 401) {
    return res.status(401).json({
      success: false,
      message: "Unauthorized",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
  
  return res.status(500).json({
    success: false,
    message: "Internal server error",
    error: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong'
  });
}

// Main handler
export default async function handler(req, res) {
  try {
    // Set CORS headers
    setCorsHeaders(req, res);
    
    // Handle preflight requests
    if (req.method === 'OPTIONS') {
      return res.status(200).end();
    }

    // Validate environment variables
    validateEnvironment();
    
    // Initialize Firebase
    initFirebase();

    const { method } = req;
    const path = req.url?.split('?')[0] || '/';

    console.log(`📝 ${method} ${path} - ${new Date().toISOString()}`);

    // Root endpoint
    if (method === 'GET' && path === '/') {
      return res.status(200).json({
        message: "Payment Backend Server - Vercel Edition",
        version: "1.1.0",
        status: "active",
        firebase_enabled: firebaseEnabled,
        environment: process.env.NODE_ENV || 'development',
        timestamp: new Date().toISOString(),
        endpoints: {
          "GET /": "API Information",
          "GET /health": "Health Check",
          "POST /reset": "Send OTP Email",
          "POST /generate-snap-token": "Create Payment Token",
          "POST /midtrans-webhook": "Payment Webhook Handler",
          "GET /payment-status/:orderId": "Check Payment Status"
        }
      });
    }

    // Health check endpoint
    if (method === 'GET' && path === '/health') {
      return res.status(200).json({
        status: "healthy",
        services: {
          firebase: firebaseEnabled,
          midtrans: !!process.env.MIDTRANS_SERVER_KEY,
          mailersend: !!process.env.MAILERSEND_API_KEY
        },
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage()
      });
    }

    // Send OTP email endpoint
    if (method === 'POST' && path === '/reset') {
      const { from, to, subject, html } = req.body;

      // Validate required fields
      if (!from || !to || !subject || !html) {
        return res.status(400).json({ 
          success: false,
          message: "Missing required fields: from, to, subject, html" 
        });
      }

      // Validate email format
      if (!validateEmail(from) || !validateEmail(to)) {
        return res.status(400).json({ 
          success: false,
          message: "Invalid email format" 
        });
      }

      // Check if email service is configured
      if (!process.env.MAILERSEND_API_KEY) {
        return res.status(500).json({ 
          success: false,
          message: "Email service not configured" 
        });
      }

      try {
        const response = await axios.post(
          "https://api.mailersend.com/v1/email",
          {
            from: { email: sanitizeInput(from) },
            to: [{ email: sanitizeInput(to) }],
            subject: sanitizeInput(subject),
            html: html,
          },
          {
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${process.env.MAILERSEND_API_KEY}`,
            },
            timeout: 20000,
          }
        );

        return res.status(200).json({ 
          success: true,
          message: "Email sent successfully",
          message_id: response.data?.message_id || 'sent'
        });
      } catch (error) {
        console.error("Email sending error:", error.response?.data || error.message);
        return res.status(500).json({ 
          success: false,
          message: "Failed to send email",
          error: error.response?.data?.message || error.message
        });
      }
    }

    // Generate payment token endpoint
    if (method === 'POST' && path === '/generate-snap-token') {
      const { order_id, gross_amount, customer_details, item_details, payment_type } = req.body;

      // Validate required fields
      if (!order_id || !gross_amount || !customer_details || !item_details) {
        return res.status(400).json({ 
          success: false,
          message: "Missing required fields: order_id, gross_amount, customer_details, item_details" 
        });
      }

      // Validate order_id format
      if (!validateOrderId(order_id)) {
        return res.status(400).json({ 
          success: false,
          message: "Invalid order_id format. Only alphanumeric characters, hyphens, underscores, and dots are allowed." 
        });
      }

      // Validate amount
      const amount = parseInt(gross_amount);
      if (isNaN(amount) || amount < 0) {
        return res.status(400).json({ 
          success: false,
          message: "Invalid gross_amount. Must be a valid positive number." 
        });
      }

      // Validate customer email if provided
      if (customer_details.email && !validateEmail(customer_details.email)) {
        return res.status(400).json({ 
          success: false,
          message: "Invalid customer email format" 
        });
      }

      const serverKey = process.env.MIDTRANS_SERVER_KEY;
      const encodedKey = Buffer.from(serverKey + ":").toString("base64");

      // Build transaction data
      const transactionData = {
        transaction_details: { 
          order_id: sanitizeInput(order_id), 
          gross_amount: amount 
        },
        customer_details: {
          first_name: sanitizeInput(customer_details.first_name) || "Customer",
          last_name: sanitizeInput(customer_details.last_name) || "",
          email: sanitizeInput(customer_details.email) || "",
          phone: sanitizeInput(customer_details.phone) || "",
        },
        item_details: item_details.map(item => ({
          id: sanitizeInput(item.id),
          price: parseInt(item.price),
          quantity: parseInt(item.quantity),
          name: sanitizeInput(item.name),
        })),
        credit_card: { secure: true }
      };

      try {
        const baseUrl = process.env.MIDTRANS_IS_PRODUCTION === 'true' 
          ? 'https://app.midtrans.com' 
          : 'https://app.sandbox.midtrans.com';

        const response = await axios.post(
          `${baseUrl}/snap/v1/transactions`,
          transactionData,
          {
            headers: {
              "Content-Type": "application/json",
              Authorization: `Basic ${encodedKey}`,
            },
            timeout: 20000,
          }
        );

        // Save to Firebase with enhanced data structure
        if (firebaseEnabled) {
          try {
            const paymentData = {
              order_id: sanitizeInput(order_id),
              status: "pending",
              is_paid: false,
              gross_amount: amount,
              customer_details: {
                first_name: sanitizeInput(customer_details.first_name) || "Customer",
                last_name: sanitizeInput(customer_details.last_name) || "",
                email: sanitizeInput(customer_details.email) || "",
                phone: sanitizeInput(customer_details.phone) || "",
              },
              item_details,
              payment_type: payment_type || 'general',
              snap_token: response.data.token,
              transaction_status: "pending",
              created_at: admin.firestore.FieldValue.serverTimestamp(),
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
              // Handle specific payment types
              ...(payment_type === 'event' && {
                userId: customer_details.userId,
                eventId: customer_details.eventId,
                eventName: customer_details.eventName,
                eventData: customer_details.eventData,
                userEmail: sanitizeInput(customer_details.email),
                userName: sanitizeInput(customer_details.first_name),
                quantity: item_details[0]?.quantity || 1,
                totalAmount: amount,
                isFree: amount === 0
              }),
              ...(payment_type === 'destination' && {
                userId: customer_details.userId,
                destinasiId: customer_details.destinasiId,
                destinasiName: customer_details.destinasiName,
                destinasiData: customer_details.destinasiData,
                userEmail: sanitizeInput(customer_details.email),
                userName: sanitizeInput(customer_details.first_name),
                quantity: item_details[0]?.quantity || 1,
                totalAmount: amount,
                isFree: amount === 0
              })
            };

            await db.collection("payments").add(paymentData);
            console.log(`💾 Payment record created for ${order_id} with status: pending`);
          } catch (firebaseError) {
            console.error("Firebase save error:", firebaseError.message);
            // Continue even if Firebase fails
          }
        }

        return res.status(200).json({
          success: true,
          snap_token: response.data.token,
          redirect_url: response.data.redirect_url,
          order_id: order_id,
          gross_amount: amount
        });

      } catch (error) {
        console.error("Payment token generation error:", error.response?.data || error.message);
        return res.status(500).json({ 
          success: false,
          message: "Failed to generate payment token",
          error: error.response?.data?.error_messages || error.message
        });
      }
    }

    // Midtrans webhook endpoint
    if (method === 'POST' && path === '/midtrans-webhook') {
      const { order_id, status_code, gross_amount, signature_key, transaction_status } = req.body;

      // Validate required webhook fields
      if (!order_id || !status_code || !gross_amount || !signature_key) {
        return res.status(400).json({ 
          success: false,
          message: "Missing required webhook fields" 
        });
      }

      // Verify signature
      const serverKey = process.env.MIDTRANS_SERVER_KEY;
      const expectedSignature = crypto
        .createHash("sha512")
        .update(order_id + status_code + gross_amount + serverKey)
        .digest("hex");

      if (signature_key !== expectedSignature) {
        console.error(`❌ Invalid signature for order ${order_id}`);
        return res.status(401).json({ 
          success: false,
          message: "Invalid signature" 
        });
      }

      const statusInfo = mapTransactionStatus(transaction_status);
      console.log(`🔔 Webhook received for ${order_id}: ${transaction_status} -> ${statusInfo.status}`);

      // Update Firebase
      if (firebaseEnabled) {
        try {
          const paymentsRef = db.collection("payments");
          const snapshot = await paymentsRef.where("order_id", "==", order_id).get();
          
          if (!snapshot.empty) {
            const doc = snapshot.docs[0];
            await doc.ref.update({
              status: statusInfo.status,
              is_paid: statusInfo.isPaid,
              transaction_status,
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`💾 Webhook updated ${order_id}: ${statusInfo.status}, isPaid: ${statusInfo.isPaid}`);
          } else {
            console.log(`⚠️ No payment record found for ${order_id}`);
          }
        } catch (firebaseError) {
          console.error("Firebase update error:", firebaseError.message);
        }
      }

      return res.status(200).json({ 
        success: true,
        message: "Webhook processed successfully", 
        order_id, 
        status: statusInfo.status 
      });
    }

    // Check payment status endpoint
    if (method === 'GET' && path.startsWith('/payment-status/')) {
      const orderId = path.split('/payment-status/')[1];
      
      if (!orderId) {
        return res.status(400).json({ 
          success: false,
          message: "Order ID is required" 
        });
      }

      // Validate order ID format
      if (!validateOrderId(orderId)) {
        return res.status(400).json({ 
          success: false,
          message: "Invalid order ID format" 
        });
      }

      console.log(`🔍 Checking payment status for order: ${orderId}`);

      // Check Midtrans directly
      let midtransData = null;
      let midtransError = null;
      
      try {
        midtransData = await checkMidtransStatus(orderId);
        console.log(`📡 Midtrans status for ${orderId}: ${midtransData.transaction_status}`);
      } catch (error) {
        midtransError = error.message;
        console.log(`⚠️ Could not fetch from Midtrans for ${orderId}: ${error.message}`);
      }

      // Check Firebase
      let firebaseData = null;
      let firebaseUpdateSuccess = false;
      
      if (firebaseEnabled) {
        try {
          const snapshot = await db.collection("payments")
            .where("order_id", "==", orderId)
            .get();

          if (!snapshot.empty) {
            firebaseData = snapshot.docs[0].data();
            
            // Update Firebase with latest Midtrans data
            if (midtransData) {
              const statusInfo = mapTransactionStatus(midtransData.transaction_status);

              await snapshot.docs[0].ref.update({
                status: statusInfo.status,
                is_paid: statusInfo.isPaid,
                transaction_status: midtransData.transaction_status,
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              });

              firebaseData = { 
                ...firebaseData, 
                status: statusInfo.status, 
                is_paid: statusInfo.isPaid,
                transaction_status: midtransData.transaction_status
              };
              firebaseUpdateSuccess = true;
              
              console.log(`💾 Firebase updated for ${orderId}: ${statusInfo.status}, isPaid: ${statusInfo.isPaid}`);
            }
          }
        } catch (firebaseError) {
          console.error("Firebase query error:", firebaseError.message);
        }
      }

      if (!firebaseData && !midtransData) {
        return res.status(404).json({ 
          success: false,
          message: "Payment not found",
          order_id: orderId,
          ...(midtransError && { midtrans_error: midtransError })
        });
      }

      const currentTransactionStatus = midtransData ? midtransData.transaction_status : firebaseData?.transaction_status;
      const statusInfo = mapTransactionStatus(currentTransactionStatus);

      let message = "Payment status unknown";
      switch (statusInfo.status) {
        case "success":
          message = "Payment successful!";
          break;
        case "pending":
          message = "Payment is pending";
          break;
        case "cancelled":
          message = "Payment was cancelled";
          break;
        case "expired":
          message = "Payment has expired";
          break;
        case "failed":
          message = "Payment failed";
          break;
        default:
          message = `Payment status: ${currentTransactionStatus}`;
      }

      return res.status(200).json({
        success: true,
        order_id: orderId,
        status: statusInfo.status,
        is_paid: statusInfo.isPaid,
        can_navigate_home: statusInfo.canNavigateHome,
        transaction_status: currentTransactionStatus,
        message,
        timestamp: new Date().toISOString(),
        sources: {
          firebase: !!firebaseData,
          midtrans: !!midtransData,
          firebase_update_success: firebaseUpdateSuccess
        },
        ...(midtransData && {
          fraud_status: midtransData.fraud_status,
          payment_type: midtransData.payment_type,
          gross_amount: midtransData.gross_amount,
          transaction_time: midtransData.transaction_time
        })
      });
    }

    // 404 for unmatched routes
    return res.status(404).json({ 
      success: false,
      message: "Endpoint not found",
      path: path,
      method: method,
      available_endpoints: [
        "GET /",
        "GET /health",
        "POST /reset",
        "POST /generate-snap-token",
        "POST /midtrans-webhook",
        "GET /payment-status/:orderId"
      ]
    });

  } catch (error) {
    return handleError(error, res, 'main handler');
  }
}