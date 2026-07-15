# =====================================================
# eSIMNest - Global Data eSIM
# A Tech Talk Titans Product
# Backend API - FastAPI
# ====================================================

from fastapi import FastAPI, HTTPException, Depends, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional, List
import firebase_admin
from firebase_admin import credentials, firestore, auth
import requests
import json
import os
from datetime import datetime, timedelta
import secrets
import hashlib
import hmac
import time
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import razorpay
from razorpay.errors import SignatureVerificationError

# =====================================================
# 1. INITIALIZATION
# =====================================================

app = FastAPI(
    title="eSIMNest API",
    description="eSIMNest - Global Data eSIM Platform API",
    version="1.0.0"
)

# CORS - Allow your Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://esmnst-frontend.onrender.com",  # Your frontend's exact URL
        "https://esmnst.onrender.com",           # Your backend URL for testing
        "http://localhost:3000",                 # For local development
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =====================================================
# 2. FIREBASE INITIALIZATION
# =====================================================

try:
    if os.getenv('FIREBASE_CREDENTIALS'):
        cred = credentials.Certificate(json.loads(os.getenv('FIREBASE_CREDENTIALS')))
    else:
        cred = credentials.Certificate("service-account.json")
    
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase initialized successfully")
except Exception as e:
    print(f"❌ Firebase initialization error: {e}")

# =====================================================
# 3. eSIM ACCESS API CONFIGURATION (REAL PROVIDER)
# =====================================================

ESIM_ACCESS_CODE = os.getenv('ESIM_ACCESS_CODE')
ESIM_API_URL = os.getenv('ESIM_API_URL', 'https://api.esimaccess.com')
MARKUP_MULTIPLIER = float(os.getenv('MARKUP_MULTIPLIER', '2.0'))
RAZORPAY_KEY_ID = os.getenv('RAZORPAY_KEY_ID')
RAZORPAY_KEY_SECRET = os.getenv('RAZORPAY_KEY_SECRET')
razorpay_client = razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))

# =====================================================
# 4. eSIM ACCESS AUTHENTICATION (UPDATED)
# =====================================================

def get_esim_headers():
    """Generate headers for eSIM Access API - using RT-AccessCode header"""
    return {
        "RT-AccessCode": ESIM_ACCESS_CODE,
        "Content-Type": "application/json"
    }

# =====================================================
# 5. PYDANTIC MODELS (Data Validation)
# =====================================================

class UserRegister(BaseModel):
    email: EmailStr
    password: str
    displayName: str
    phone: str
    country: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class AddMoneyRequest(BaseModel):
    amount: float
    currency: str = "USD"
    method: str  # "razorpay", "paypal", "manual"

class ManualPaymentRequest(BaseModel):
    method_name: str
    amount: float
    reference_number: str
    notes: Optional[str] = ""

class PurchasePlan(BaseModel):
    plan_id: str
    country: str

# =====================================================
# 6. AUTHENTICATION HELPERS
# =====================================================

async def get_current_user(authorization: str = Header(...)):
    try:
        token = authorization.split(' ')[1]
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid authentication")

def create_user_document(uid: str, user_data: dict):
    try:
        user_ref = db.collection('users').document(uid)
        user_ref.set({
            'email': user_data['email'],
            'displayName': user_data.get('displayName', ''),
            'phone': user_data.get('phone', ''),
            'country': user_data.get('country', ''),
            'walletBalance': 0.0,
            'walletCurrency': 'USD',
            'role': 'user',
            'kycVerified': False,
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
            'referralCode': generate_referral_code(),
            'referredBy': user_data.get('referredBy', '')
        })
        return True
    except Exception as e:
        print(f"Error creating user document: {e}")
        return False

def generate_referral_code():
    return secrets.token_hex(4).upper()

# =====================================================
# 7. AUTHENTICATION ENDPOINTS
# =====================================================

# =====================================================
# 11.5 SIMPLE WEBHOOK (For eSIM Access)
# =====================================================


# =====================================================
# DEBUG ENDPOINTS - No Auth Required
# =====================================================

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "eSIMNest API is running!",
        "version": "1.0.0",
        "routes": [
            "/",
            "/api/health",
            "/api/test",
            "/api/debug",
            "/api/esim/countries",
            "/api/esim/plans",
            "/api/esim/purchase",
            "/api/auth/register"
        ]
    }

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "eSIMNest API",
        "version": "1.0.0",
        "brand": "eSIMNest",
        "slogan": "Global Data eSIM",
        "company": "Tech Talk Titans"
    }

@app.get("/api/test")
async def test():
    """Simple test endpoint"""
    return {"status": "ok", "message": "Backend is working!"}

@app.get("/api/debug")
async def debug():
    """Debug endpoint showing environment"""
    return {
        "esim_access_code_set": bool(ESIM_ACCESS_CODE),
        "markup": MARKUP_MULTIPLIER,
        "api_url": ESIM_API_URL
    }

# =====================================================
# REST OF YOUR CODE BELOW...
# =====================================================

@app.post("/api/payment/paypal/create-order")
async def create_paypal_order(request: dict, user: dict = Depends(get_current_user)):
    try:
        amount = request.get('amount', 0)
        currency = request.get('currency', 'USD')
        
        if amount <= 0:
            raise HTTPException(status_code=400, detail="Invalid amount")
        
        # PayPal API call (simplified - use actual PayPal SDK in production)
        # For now, return a mock response
        return {
            "success": True,
            "payment_id": f"PAY-{secrets.token_hex(8)}",
            "approval_url": f"https://www.paypal.com/checkoutnow?token={secrets.token_hex(16)}"
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/payment/paypal/capture")
async def capture_paypal_payment(request: dict, user: dict = Depends(get_current_user)):
    try:
        payment_id = request.get('payment_id')
        
        # In production, call PayPal API to capture payment
        # For now, simulate successful capture
        
        # Credit wallet
        db.collection('users').document(user['uid']).update({
            'walletBalance': firestore.Increment(100.0)  # Mock amount
        })
        
        db.collection('transactions').add({
            'userId': user['uid'],
            'type': 'credit',
            'amount': 100.0,
            'currency': 'USD',
            'description': f'Added via PayPal (Payment: {payment_id})',
            'status': 'completed',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        return {
            "success": True,
            "message": "Payment captured successfully",
            "amount": 100.0
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/payment/razorpay/create-order")
async def create_razorpay_order(request: dict, user: dict = Depends(get_current_user)):
    """Create a Razorpay order"""
    try:
        uid = user['uid']
        amount = request.get('amount')
        
        if not amount or amount <= 0:
            raise HTTPException(status_code=400, detail="Invalid amount")
        
        # Create order in Razorpay
        order_data = {
            'amount': int(amount * 100),  # Convert to paise
            'currency': 'INR',
            'receipt': f'{user["uid"][:20]}_{int(time.time())}'[:40],
            'payment_capture': 1
        }
        
        order = razorpay_client.order.create(data=order_data)
        
        # Store in Firestore
        db.collection('razorpay_orders').document(order['id']).set({
            'userId': uid,
            'amount': amount,
            'order_id': order['id'],
            'status': 'created',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        return {
            'success': True,
            'order_id': order['id'],
            'amount': amount,
            'currency': 'INR',
            'key': RAZORPAY_KEY_ID
        }
        
    except Exception as e:
        print(f"Razorpay error: {e}")
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/payment/razorpay/verify")
async def verify_razorpay_payment(request: dict, user: dict = Depends(get_current_user)):
    """Verify Razorpay payment signature"""
    try:
        uid = user['uid']
        payment_id = request.get('razorpay_payment_id')
        order_id = request.get('razorpay_order_id')
        signature = request.get('razorpay_signature')
        
        # Verify signature
        params_dict = {
            'razorpay_payment_id': payment_id,
            'razorpay_order_id': order_id,
            'razorpay_signature': signature
        }
        
        razorpay_client.utility.verify_payment_signature(params_dict)
        
        # Get order details
        order_ref = db.collection('razorpay_orders').document(order_id)
        order_doc = order_ref.get()
        
        if not order_doc.exists:
            raise HTTPException(status_code=404, detail="Order not found")
        
        order_data = order_doc.to_dict()
        amount = order_data.get('amount', 0)
        
        # Credit wallet
        user_ref = db.collection('users').document(uid)
        user_ref.update({
            'walletBalance': firestore.Increment(amount)
        })
        
        # Log transaction
        db.collection('transactions').add({
            'userId': uid,
            'type': 'credit',
            'amount': amount,
            'currency': 'INR',
            'description': f'Added money via Razorpay (Payment ID: {payment_id})',
            'reference': payment_id,
            'status': 'completed',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # Update order status
        order_ref.update({
            'status': 'completed',
            'payment_id': payment_id,
            'verifiedAt': firestore.SERVER_TIMESTAMP
        })
        
        return {
            'success': True,
            'message': 'Payment verified successfully',
            'amount': amount
        }
        
    except SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Signature verification failed")
    except Exception as e:
        print(f"Verification error: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/webhook")
async def simple_webhook(request: Request):
    """Simple webhook endpoint for eSIM Access"""
    try:
        # Get the raw body
        body = await request.body()
        print(f"📨 Webhook received at /webhook")
        print(f"Headers: {request.headers}")
        print(f"Body: {body}")
        
        # Try to parse as JSON
        try:
            data = json.loads(body)
            print(f"JSON data: {data}")
        except:
            print("Body is not JSON")
        
        # Always return 200 to acknowledge receipt
        return {"status": "received", "timestamp": datetime.now().isoformat()}
    except Exception as e:
        print(f"❌ Webhook error: {e}")
        return {"status": "error", "message": str(e)}


@app.post("/api/auth/register")
async def register_user(user_data: UserRegister):
    try:
        user = auth.create_user(
            email=user_data.email,
            password=user_data.password,
            display_name=user_data.displayName,
            phone_number=user_data.phone
        )
        
        create_user_document(user.uid, user_data.dict())
        
        send_email_trigger(
            to=user_data.email,
            subject="Welcome to eSIMNest! 🎉",
            html=welcome_email_template(user_data.displayName)
        )
        
        return {
            "success": True,
            "message": "User registered successfully",
            "uid": user.uid
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/auth/verify-token")
async def verify_token(user: dict = Depends(get_current_user)):
    return {
        "success": True,
        "user": {
            "uid": user['uid'],
            "email": user.get('email'),
            "name": user.get('name', '')
        }
    }

# =====================================================
# 8. USER ENDPOINTS
# =====================================================

@app.get("/api/user/profile")
async def get_user_profile(user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        
        data = user_doc.to_dict()
        data['uid'] = uid
        return data
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.put("/api/user/profile")
async def update_user_profile(updates: dict, user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        
        updates.pop('uid', None)
        updates.pop('createdAt', None)
        updates.pop('walletBalance', None)
        updates['updatedAt'] = firestore.SERVER_TIMESTAMP
        
        user_ref.update(updates)
        return {"success": True, "message": "Profile updated"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/user/dashboard")
async def get_dashboard(user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_data = user_doc.to_dict()
        
        esims_ref = db.collection('esims').where('userId', '==', uid).where('status', '==', 'active')
        active_esims = esims_ref.get()
        
        orders_ref = db.collection('orders').where('userId', '==', uid)
        total_orders = orders_ref.get()
        
        recent_orders_ref = db.collection('orders').where('userId', '==', uid).order_by('createdAt', direction=firestore.Query.DESCENDING).limit(5)
        recent_orders = recent_orders_ref.get()
        
        active_esims_ref = db.collection('esims').where('userId', '==', uid).where('status', '==', 'active').limit(3)
        active_esims_data = active_esims_ref.get()
        
        return {
            "walletBalance": user_data.get('walletBalance', 0),
            "walletCurrency": user_data.get('walletCurrency', 'USD'),
            "activeEsimsCount": len(active_esims),
            "totalOrdersCount": len(total_orders),
            "recentOrders": [
                {
                    'id': doc.id,
                    'plan': doc.to_dict().get('plan', {}),
                    'amount': doc.to_dict().get('amount', 0),
                    'status': doc.to_dict().get('status', ''),
                    'createdAt': doc.to_dict().get('createdAt')
                }
                for doc in recent_orders
            ],
            "activeEsims": [
                {
                    'id': doc.id,
                    'country': doc.to_dict().get('country', ''),
                    'plan': doc.to_dict().get('plan', ''),
                    'iccid': doc.to_dict().get('iccid', ''),
                    'expiry': doc.to_dict().get('expiryDate')
                }
                for doc in active_esims_data
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# =====================================================
# 9. WALLET ENDPOINTS
# =====================================================

@app.get("/api/wallet/balance")
async def get_wallet_balance(user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        
        data = user_doc.to_dict()
        return {
            "balance": data.get('walletBalance', 0),
            "currency": data.get('walletCurrency', 'USD')
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/wallet/add-money")
async def add_money(request: AddMoneyRequest, user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        
        payment_ref = db.collection('paymentRequests').add({
            'userId': uid,
            'method': request.method,
            'amount': request.amount,
            'currency': request.currency,
            'status': 'pending',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        if request.method == 'razorpay':
            razorpay_response = create_razorpay_order(request.amount, request.currency)
            return {
                "success": True,
                "payment_id": payment_ref[1].id,
                "razorpay_order_id": razorpay_response.get('id'),
                "amount": request.amount,
                "currency": request.currency
            }
        elif request.method == 'paypal':
            paypal_response = create_paypal_order(request.amount, request.currency)
            return {
                "success": True,
                "payment_id": payment_ref[1].id,
                "paypal_order_id": paypal_response.get('id'),
                "amount": request.amount,
                "currency": request.currency
            }
        else:
            return {
                "success": True,
                "payment_id": payment_ref[1].id,
                "message": "Manual payment request created",
                "amount": request.amount,
                "currency": request.currency
            }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/wallet/verify-payment")
async def verify_payment(payment_data: dict, user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        payment_id = payment_data.get('payment_id')
        payment_method = payment_data.get('method')
        
        verified = False
        if payment_method == 'razorpay':
            verified = verify_razorpay_payment(payment_data)
        elif payment_method == 'paypal':
            verified = verify_paypal_payment(payment_data)
        
        if not verified:
            raise HTTPException(status_code=400, detail="Payment verification failed")
        
        payment_ref = db.collection('paymentRequests').document(payment_id)
        payment_doc = payment_ref.get()
        
        if not payment_doc.exists:
            raise HTTPException(status_code=404, detail="Payment not found")
        
        payment_data = payment_doc.to_dict()
        
        amount = payment_data.get('amount', 0)
        user_ref = db.collection('users').document(uid)
        
        user_ref.update({
            'walletBalance': firestore.Increment(amount)
        })
        
        db.collection('transactions').add({
            'userId': uid,
            'type': 'credit',
            'amount': amount,
            'currency': payment_data.get('currency', 'USD'),
            'description': f'Added money via {payment_method}',
            'reference': payment_data.get('reference', ''),
            'status': 'completed',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        user_doc = db.collection('users').document(uid).get()
        user_email = user_doc.to_dict().get('email')
        user_name = user_doc.to_dict().get('displayName', '')
        
        send_email_trigger(
            to=user_email,
            subject="Payment Received ✅",
            html=payment_confirmation_email(user_name, amount, payment_method)
        )
        
        return {
            "success": True,
            "message": "Payment verified, wallet credited",
            "amount": amount,
            "new_balance": amount + payment_data.get('previous_balance', 0)
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/wallet/transactions")
async def get_transactions(
    limit: Optional[int] = 100,
    offset: Optional[int] = 0,
    user: dict = Depends(get_current_user)
):
    try:
        uid = user['uid']
        trans_ref = db.collection('transactions').where('userId', '==', uid).order_by('createdAt', direction=firestore.Query.DESCENDING).limit(limit)
        trans_docs = trans_ref.get()
        
        transactions = []
        for doc in trans_docs:
            data = doc.to_dict()
            data['id'] = doc.id
            transactions.append(data)
        
        return {
            "transactions": transactions,
            "total": len(transactions),
            "limit": limit,
            "offset": offset
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# =====================================================
# 10. eSIM ACCESS ENDPOINTS (UPDATED)
# =====================================================

# 10.1 Get Provider Balance
@app.get("/api/esim/provider-balance")
async def get_provider_balance(user: dict = Depends(get_current_user)):
    """Get current balance from eSIM Access (Admin only)"""
    try:
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists or user_doc.to_dict().get('role') != 'admin':
            raise HTTPException(status_code=403, detail="Admin access required")
        
        response = requests.post(
            f"{ESIM_API_URL}/api/v1/open/balance/query",
            headers=get_esim_headers(),
            json={},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                balance = data.get('obj', {}).get('balance', 0)
                return {
                    "success": True,
                    "balance": balance,
                    "currency": "USD"
                }
        
        return {"success": False, "error": "Failed to get balance"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# 10.2 Get Available Countries (REAL API)
@app.get("/api/esim/countries")
async def get_countries(user: dict = Depends(get_current_user)):
    """Get all available countries from eSIM Access"""
    try:
        if not ESIM_ACCESS_CODE:
            print("⚠️ ESIM_ACCESS_CODE not set, returning mock data")
            return get_mock_countries()
        
        # Try to call the eSIM Access API
        print(f"🔍 Calling eSIM API at: {ESIM_API_URL}/api/v1/open/country/list")
        
        response = requests.post(
            f"{ESIM_API_URL}/api/v1/open/country/list",
            headers=get_esim_headers(),
            json={},
            timeout=10
        )
        
        print(f"🔍 Countries API response status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                countries = data.get('obj', {}).get('countryList', [])
                formatted_countries = []
                for country in countries:
                    formatted_countries.append({
                        "code": country.get('countryCode', ''),
                        "name": country.get('countryName', ''),
                    })
                return {
                    "success": True,
                    "countries": formatted_countries,
                    "total": len(formatted_countries)
                }
            else:
                print(f"❌ API error: {data.get('errorMsg', 'Unknown')}")
                return get_mock_countries()
        else:
            print(f"❌ API returned status: {response.status_code}, response: {response.text}")
            return get_mock_countries()
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Network error: {e}")
        return get_mock_countries()
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return get_mock_countries()

def get_mock_countries():
    """Fallback mock countries"""
    return {
        "success": True,
        "countries": [
            {"code": "US", "name": "United States"},
            {"code": "IN", "name": "India"},
            {"code": "GB", "name": "United Kingdom"},
            {"code": "JP", "name": "Japan"},
            {"code": "FR", "name": "France"},
            {"code": "DE", "name": "Germany"},
            {"code": "AE", "name": "UAE"},
            {"code": "SG", "name": "Singapore"},
            {"code": "AU", "name": "Australia"},
            {"code": "CA", "name": "Canada"},
        ],
        "total": 10
    }

# 10.3 Get Plans for a Country (IMPROVED)
@app.get("/api/esim/plans")
async def get_plans(
    country: Optional[str] = None,
    user: dict = Depends(get_current_user)
):
    """Get eSIM plans from eSIM Access with markup applied"""
    try:
        if not ESIM_ACCESS_CODE:
            print("⚠️ ESIM_ACCESS_CODE not set, returning mock plans")
            return get_mock_plans(country)
        
        payload = {}
        if country:
            payload["locationCode"] = country
        
        print(f"🔍 Fetching plans for country: {country}")
        
        response = requests.post(
            f"{ESIM_API_URL}/api/v1/open/package/list",
            headers=get_esim_headers(),
            json=payload,
            timeout=30
        )
        
        print(f"🔍 Plans API response status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"🔍 Plans API response: {data}")
            
            if data.get('success'):
                packages = data.get('obj', {}).get('packageList', [])
                
                if not packages:
                    print(f"⚠️ No packages found for country: {country}")
                    return {"success": True, "plans": [], "total": 0}
                
                formatted_plans = []
                for plan in packages:
                    wholesale_price_cents = plan.get('price', 0)
                    print(f"🔍 wholesale_price_cents: {wholesale_price_cents}")  # Should print 70
                    wholesale_price = wholesale_price_cents / 100
                    print(f"🔍 wholesale_price: {wholesale_price}")  # Should print 0.70
                    retail_price = wholesale_price * MARKUP_MULTIPLIER
                    print(f"🔍 retail_price: {retail_price}")  # Should print 1.47
                    
                    formatted_plans.append({
                        "id": plan.get('packageCode', ''),
                        "name": plan.get('name', 'Data Plan'),
                        "country": plan.get('locationName', country or 'Unknown'),
                        "countryCode": plan.get('locationCode', ''),
                        "data": plan.get('volume', 0),
                        "validity": plan.get('duration', 7),
                        "wholesale_price": wholesale_price,
                        "price": retail_price,
                        "currency": "USD",
                        "markup": MARKUP_MULTIPLIER,
                        "type": plan.get('type', 'data'),
                        "description": plan.get('description', '')
                    })
                
                return {
                    "success": True,
                    "plans": formatted_plans,
                    "total": len(formatted_plans)
                }
            else:
                print(f"❌ API returned error: {data.get('errorMsg', 'Unknown error')}")
                return get_mock_plans(country)
        else:
            print(f"❌ API returned status: {response.status_code}")
            return get_mock_plans(country)
            
    except Exception as e:
        print(f"❌ Plans API error: {e}")
        return get_mock_plans(country)

def get_mock_plans(country):
    """Fallback mock plans"""
    plans = {
        "US": [
            {"id": "plan_us_1", "name": "1GB Data", "country": "United States", "data": 1, "validity": 7, "price": 10.00},
            {"id": "plan_us_2", "name": "3GB Data", "country": "United States", "data": 3, "validity": 15, "price": 20.00},
            {"id": "plan_us_3", "name": "5GB Data", "country": "United States", "data": 5, "validity": 30, "price": 30.00},
            {"id": "plan_us_4", "name": "10GB Data", "country": "United States", "data": 10, "validity": 30, "price": 50.00},
        ],
        "IN": [
            {"id": "plan_in_1", "name": "1GB Data", "country": "India", "data": 1, "validity": 7, "price": 5.00},
            {"id": "plan_in_2", "name": "3GB Data", "country": "India", "data": 3, "validity": 15, "price": 12.00},
            {"id": "plan_in_3", "name": "5GB Data", "country": "India", "data": 5, "validity": 30, "price": 20.00},
        ],
        "GB": [
            {"id": "plan_gb_1", "name": "1GB Data", "country": "United Kingdom", "data": 1, "validity": 7, "price": 8.00},
            {"id": "plan_gb_2", "name": "3GB Data", "country": "United Kingdom", "data": 3, "validity": 15, "price": 15.00},
            {"id": "plan_gb_3", "name": "5GB Data", "country": "United Kingdom", "data": 5, "validity": 30, "price": 25.00},
        ],
        "JP": [
            {"id": "plan_jp_1", "name": "1GB Data", "country": "Japan", "data": 1, "validity": 7, "price": 12.00},
            {"id": "plan_jp_2", "name": "3GB Data", "country": "Japan", "data": 3, "validity": 15, "price": 25.00},
            {"id": "plan_jp_3", "name": "5GB Data", "country": "Japan", "data": 5, "validity": 30, "price": 40.00},
        ],
        "FR": [
            {"id": "plan_fr_1", "name": "1GB Data", "country": "France", "data": 1, "validity": 7, "price": 8.00},
            {"id": "plan_fr_2", "name": "3GB Data", "country": "France", "data": 3, "validity": 15, "price": 18.00},
        ],
        "DE": [
            {"id": "plan_de_1", "name": "1GB Data", "country": "Germany", "data": 1, "validity": 7, "price": 8.00},
            {"id": "plan_de_2", "name": "3GB Data", "country": "Germany", "data": 3, "validity": 15, "price": 18.00},
        ],
        "AE": [
            {"id": "plan_ae_1", "name": "1GB Data", "country": "UAE", "data": 1, "validity": 7, "price": 10.00},
            {"id": "plan_ae_2", "name": "3GB Data", "country": "UAE", "data": 3, "validity": 15, "price": 22.00},
        ],
        "SG": [
            {"id": "plan_sg_1", "name": "1GB Data", "country": "Singapore", "data": 1, "validity": 7, "price": 8.00},
            {"id": "plan_sg_2", "name": "3GB Data", "country": "Singapore", "data": 3, "validity": 15, "price": 18.00},
        ],
    }
    
    if country and country in plans:
        return {"success": True, "plans": plans[country], "total": len(plans[country])}
    
    # Return all plans if no country specified
    all_plans = []
    for p in plans.values():
        all_plans.extend(p)
    return {"success": True, "plans": all_plans, "total": len(all_plans)}



# 10.4 Purchase eSIM (UPDATED - Endpoint changed)
@app.post("/api/esim/purchase")
async def purchase_esim(purchase: PurchasePlan, user: dict = Depends(get_current_user)):
    """Purchase an eSIM from eSIM Access"""
    try:
        uid = user['uid']
        plan_id = purchase.plan_id
        country = purchase.country
        
        if not ESIM_ACCESS_CODE:
            raise HTTPException(status_code=400, detail="eSIM Access not configured")
        
        # Get user data
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_data = user_doc.to_dict()
        balance = user_data.get('walletBalance', 0)
        
        # Get plan details from eSIM Access
        plan_response = requests.post(
            f"{ESIM_API_URL}/api/v1/open/package/list",
            headers=get_esim_headers(),
            json={"locationCode": country} if country else {},
            timeout=10
        )
        
        if plan_response.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to get plan details")
        
        plan_data = plan_response.json()
        if not plan_data.get('success'):
            raise HTTPException(status_code=400, detail="Plan not found")
        
        # Find the specific plan
        plan = None
        for p in plan_data.get('obj', {}).get('packageList', []):
            if p.get('packageCode') == plan_id:
                plan = p
                break
        
        if not plan:
            raise HTTPException(status_code=404, detail="Plan not found")
        
        wholesale_price_cents = plan.get('price', 0)
        wholesale_price = wholesale_price_cents / 100
        retail_price = wholesale_price * MARKUP_MULTIPLIER
        
        # Check wallet balance
        if balance < retail_price:
            raise HTTPException(status_code=400, detail="Insufficient wallet balance")
        
        # Create order in Firestore
        order_ref = db.collection('orders').add({
            'userId': uid,
            'country': country,
            'plan': {
                'id': plan_id,
                'name': plan.get('name', ''),
                'data': plan.get('volume', 0),
                'validity': plan.get('duration', 7),
                'wholesale_price': wholesale_price
            },
            'amount': retail_price,
            'currency': 'USD',
            'status': 'pending',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # Generate transaction ID
        transaction_id = f"{uid}_{int(time.time())}"
        
        # 🚀 Purchase from eSIM Access
        purchase_response = requests.post(
            f"{ESIM_API_URL}/api/v1/open/order/profile",
            headers=get_esim_headers(),
            json={
                "transactionId": transaction_id,
                "packageInfoList": [
                    {
                        "packageCode": plan_id,
                        "count": 1
                    }
                ]
            },
            timeout=10
        )
        
        if purchase_response.status_code == 200:
            purchase_data = purchase_response.json()
            
            if purchase_data.get('success'):
                order_no = purchase_data.get('obj', {}).get('orderNo')
                
                # Debit wallet
                user_ref.update({
                    'walletBalance': firestore.Increment(-retail_price)
                })
                
                # Create transaction record
                db.collection('transactions').add({
                    'userId': uid,
                    'type': 'debit',
                    'amount': retail_price,
                    'currency': 'USD',
                    'description': f'Purchased eSIM for {country} - {plan.get("name", "Plan")}',
                    'reference': plan_id,
                    'status': 'completed',
                    'createdAt': firestore.SERVER_TIMESTAMP
                })
                
                # Update order with order number
                db.collection('orders').document(order_ref[1].id).update({
                    'orderNo': order_no,
                    'transactionId': transaction_id,
                    'status': 'processing'
                })
                
                # Note: eSIM is not delivered instantly
                # Webhook will notify when eSIM is ready
                
                return {
                    "success": True,
                    "order_id": order_ref[1].id,
                    "orderNo": order_no,
                    "status": "processing",
                    "message": "eSIM is being provisioned. You'll receive a notification when ready."
                }
            else:
                # Purchase failed
                error_msg = purchase_data.get('errorMsg', 'Purchase failed')
                db.collection('orders').document(order_ref[1].id).update({
                    'status': 'failed',
                    'error': error_msg
                })
                raise HTTPException(status_code=400, detail=error_msg)
        else:
            # API error
            db.collection('orders').document(order_ref[1].id).update({
                'status': 'failed',
                'error': 'Provider API error'
            })
            raise HTTPException(status_code=400, detail="Provider API error")
            
    except Exception as e:
        # Try to refund if needed
        try:
            user_ref = db.collection('users').document(uid)
            user_ref.update({
                'walletBalance': firestore.Increment(retail_price)
            })
        except:
            pass
        raise HTTPException(status_code=400, detail=str(e))


# =====================================================
# 11. WEBHOOK FOR eSIM DELIVERY (UPDATED)
# =====================================================

@app.post("/api/webhooks/esim")
async def esim_webhook(request: Request):
    """Handle eSIM Access webhook notifications"""
    try:
        body = await request.json()
        print(f"Webhook received: {json.dumps(body)}")
        
        # New webhook format from documentation
        notify_type = body.get('notifyType')
        notify_id = body.get('notifyId')
        content = body.get('content', {})
        
        if notify_type == 'ORDER_STATUS':
            order_no = content.get('orderNo')
            order_status = content.get('orderStatus')
            transaction_id = content.get('transactionId')
            
            if order_status == 'GOT_RESOURCE':
                # eSIM is ready! Query allocated profile
                profile_response = requests.post(
                    f"{ESIM_API_URL}/api/v1/open/esim/query",
                    headers=get_esim_headers(),
                    json={"orderNo": order_no},
                    timeout=10
                )
                
                if profile_response.status_code == 200:
                    profile_data = profile_response.json()
                    if profile_data.get('success'):
                        esim_list = profile_data.get('obj', {}).get('esimList', [])
                        
                        if esim_list:
                            esim_info = esim_list[0]
                            
                            # Find the order
                            orders_ref = db.collection('orders').where('orderNo', '==', order_no).limit(1)
                            orders = orders_ref.get()
                            order_doc = None
                            user_id = None
                            user_email = None
                            user_name = "Traveler"
                            
                            for doc in orders:
                                order_doc = doc
                                user_id = doc.to_dict().get('userId')
                                break
                            
                            if order_doc and user_id:
                                # Get user email
                                user_ref = db.collection('users').document(user_id)
                                user_doc = user_ref.get()
                                if user_doc.exists:
                                    user_data = user_doc.to_dict()
                                    user_email = user_data.get('email')
                                    user_name = user_data.get('displayName', 'Traveler')
                                
                                # Store eSIM details
                                esim_ref = db.collection('esims').add({
                                    'userId': user_id,
                                    'orderId': order_doc.id,
                                    'country': order_doc.to_dict().get('country', ''),
                                    'plan': order_doc.to_dict().get('plan', {}).get('name', ''),
                                    'orderNo': order_no,
                                    'transactionId': transaction_id,
                                    'esimTranNo': esim_info.get('esimTranNo'),
                                    'iccid': esim_info.get('iccid'),
                                    'qrCodeUrl': esim_info.get('qrCodeUrl'),
                                    'ac': esim_info.get('ac'),
                                    'status': 'active',
                                    'activationDate': datetime.now(),
                                    'expiryDate': datetime.now() + timedelta(days=30),
                                    'createdAt': firestore.SERVER_TIMESTAMP
                                })
                                
                                # Update order status
                                db.collection('orders').document(order_doc.id).update({
                                    'status': 'delivered',
                                    'esimId': esim_ref[1].id,
                                    'deliveredAt': firestore.SERVER_TIMESTAMP
                                })
                                
                                # Send email with QR code
                                if user_email:
                                    send_email_trigger(
                                        to=user_email,
                                        subject=f"Your eSIM is Ready! 📱",
                                        html=esim_delivery_email(
                                            user_name,
                                            order_doc.to_dict().get('country', ''),
                                            order_doc.to_dict().get('plan', {}).get('name', 'Plan'),
                                            esim_info.get('qrCodeUrl', ''),
                                            esim_info.get('ac', ''),
                                            datetime.now() + timedelta(days=30)
                                        )
                                    )
                                
                                return {"success": True}
        
        return {"success": True}
        
    except Exception as e:
        print(f"Webhook error: {e}")
        return {"success": False}

# =====================================================
# 12. ADMIN ENDPOINTS
# =====================================================

@app.get("/api/admin/dashboard")
async def admin_dashboard(user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists or user_doc.to_dict().get('role') != 'admin':
            raise HTTPException(status_code=403, detail="Admin access required")
        
        users = db.collection('users').get()
        orders = db.collection('orders').get()
        pending_orders = db.collection('orders').where('status', '==', 'pending').get()
        delivered_orders = db.collection('orders').where('status', '==', 'delivered').get()
        esims = db.collection('esims').get()
        payments = db.collection('paymentRequests').where('status', '==', 'pending').get()
        
        total_revenue = 0
        for order in orders:
            total_revenue += order.to_dict().get('amount', 0)
        
        # Also get provider balance
        provider_balance_response = await get_provider_balance(user)
        provider_balance = provider_balance_response.get('balance', 0) if provider_balance_response.get('success') else 0
        
        return {
            "totalUsers": len(users),
            "totalOrders": len(orders),
            "pendingOrders": len(pending_orders),
            "deliveredOrders": len(delivered_orders),
            "totalEsims": len(esims),
            "totalRevenue": total_revenue,
            "pendingPayments": len(payments),
            "providerBalance": provider_balance
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/admin/users")
async def get_all_users(user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists or user_doc.to_dict().get('role') != 'admin':
            raise HTTPException(status_code=403, detail="Admin access required")
        
        users_ref = db.collection('users')
        users_docs = users_ref.get()
        
        return [doc.to_dict() for doc in users_docs]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/admin/payment-requests")
async def get_payment_requests(user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists or user_doc.to_dict().get('role') != 'admin':
            raise HTTPException(status_code=403, detail="Admin access required")
        
        payments_ref = db.collection('paymentRequests').where('status', '==', 'pending')
        payments_docs = payments_ref.get()
        
        return [doc.to_dict() for doc in payments_docs]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/admin/verify-payment")
async def verify_manual_payment(data: dict, user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists or user_doc.to_dict().get('role') != 'admin':
            raise HTTPException(status_code=403, detail="Admin access required")
        
        payment_id = data.get('payment_id')
        status = data.get('status')
        
        payment_ref = db.collection('paymentRequests').document(payment_id)
        payment_doc = payment_ref.get()
        
        if not payment_doc.exists:
            raise HTTPException(status_code=404, detail="Payment not found")
        
        payment_data = payment_doc.to_dict()
        
        if status == 'approved':
            amount = payment_data.get('amount', 0)
            user_id = payment_data.get('userId')
            
            user_ref = db.collection('users').document(user_id)
            user_ref.update({
                'walletBalance': firestore.Increment(amount)
            })
            
            db.collection('transactions').add({
                'userId': user_id,
                'type': 'credit',
                'amount': amount,
                'currency': payment_data.get('currency', 'USD'),
                'description': 'Manual payment approved by admin',
                'reference': payment_id,
                'status': 'completed',
                'createdAt': firestore.SERVER_TIMESTAMP
            })
        
        payment_ref.update({
            'status': status,
            'verifiedAt': firestore.SERVER_TIMESTAMP,
            'verifiedBy': uid
        })
        
        return {"success": True, "message": f"Payment {status}"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# =====================================================
# 13. EMAIL FUNCTIONS (Firestore Trigger)
# =====================================================

def send_email_trigger(to: str, subject: str, html: str):
    try:
        db.collection('mail').add({
            'to': [to],
            'message': {
                'subject': subject,
                'html': html
            },
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        print(f"✅ Email trigger added for {to}")
        return True
    except Exception as e:
        print(f"❌ Error adding email trigger: {e}")
        return False

# =====================================================
# 14. EMAIL TEMPLATES
# =====================================================

def welcome_email_template(name: str):
    return f"""<!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; background-color: #0A1628; color: #FFFFFF; padding: 20px; }}
            .container {{ max-width: 600px; margin: 0 auto; background: linear-gradient(135deg, #0A1628, #1E3A5F); padding: 40px; border-radius: 16px; }}
            .header {{ text-align: center; padding-bottom: 30px; border-bottom: 1px solid rgba(255,255,255,0.1); }}
            .title {{ font-size: 28px; color: #F59E0B; font-weight: bold; }}
            .subtitle {{ font-size: 14px; color: #94A3B8; }}
            .content {{ padding: 30px 0; }}
            .button {{ display: inline-block; padding: 12px 30px; background: linear-gradient(135deg, #F59E0B, #D97706); color: #0A1628; text-decoration: none; border-radius: 8px; font-weight: 600; }}
            .footer {{ text-align: center; padding-top: 30px; border-top: 1px solid rgba(255,255,255,0.1); font-size: 12px; color: #64748B; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="title">eSIMNest</div>
                <div class="subtitle">Global Data eSIM</div>
                <div style="font-size: 12px; color: #64748B;">A Tech Talk Titans Product</div>
            </div>
            <div class="content">
                <h2>Welcome to eSIMNest, {name}! 🎉</h2>
                <p>Your gateway to affordable global connectivity.</p>
                <p>Get started by exploring our plans for 200+ countries at unbeatable prices.</p>
                <br>
                <center><a href="https://esmnst-frontend.onrender.com" class="button">Explore eSIMs</a></center>
                <br>
                <p>Need help? Reply to this email or visit our FAQ.</p>
                <p>Happy travels!</p>
            </div>
            <div class="footer">
                <div>© 2026 eSIMNest. A Tech Talk Titans Product</div>
                <div>support@esimnest.com | www.esimnest.com</div>
            </div>
        </div>
    </body>
    </html>"""

def payment_confirmation_email(name: str, amount: float, method: str):
    return f"""<!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; background-color: #0A1628; color: #FFFFFF; padding: 20px; }}
            .container {{ max-width: 600px; margin: 0 auto; background: linear-gradient(135deg, #0A1628, #1E3A5F); padding: 40px; border-radius: 16px; }}
            .header {{ text-align: center; padding-bottom: 30px; border-bottom: 1px solid rgba(255,255,255,0.1); }}
            .title {{ font-size: 28px; color: #F59E0B; font-weight: bold; }}
            .subtitle {{ font-size: 14px; color: #94A3B8; }}
            .amount {{ font-size: 36px; color: #F59E0B; font-weight: bold; text-align: center; padding: 20px 0; }}
            .content {{ padding: 30px 0; }}
            .button {{ display: inline-block; padding: 12px 30px; background: linear-gradient(135deg, #2563EB, #1D4ED8); color: #FFFFFF; text-decoration: none; border-radius: 8px; font-weight: 600; }}
            .footer {{ text-align: center; padding-top: 30px; border-top: 1px solid rgba(255,255,255,0.1); font-size: 12px; color: #64748B; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="title">eSIMNest</div>
                <div class="subtitle">Global Data eSIM</div>
            </div>
            <div class="content">
                <h2>Payment Received ✅</h2>
                <p>Hi {name},</p>
                <p>We've received your payment of <strong>${amount:.2f}</strong> via {method}.</p>
                <div class="amount">${amount:.2f}</div>
                <p>Your wallet has been credited. You can now purchase eSIMs for your travels.</p>
                <br>
                <center><a href="https://esmnst-frontend.onrender.com/wallet" class="button">View Wallet</a></center>
                <br>
                <p>Safe travels!</p>
            </div>
            <div class="footer">
                <div>© 2026 eSIMNest. A Tech Talk Titans Product</div>
                <div>support@esimnest.com | www.esimnest.com</div>
            </div>
        </div>
    </body>
    </html>"""

def esim_delivery_email(name: str, country: str, plan: str, qr_code: str, activation_code: str, expiry_date):
    return f"""<!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; background-color: #0A1628; color: #FFFFFF; padding: 20px; }}
            .container {{ max-width: 600px; margin: 0 auto; background: linear-gradient(135deg, #0A1628, #1E3A5F); padding: 40px; border-radius: 16px; }}
            .header {{ text-align: center; padding-bottom: 30px; border-bottom: 1px solid rgba(255,255,255,0.1); }}
            .title {{ font-size: 28px; color: #F59E0B; font-weight: bold; }}
            .subtitle {{ font-size: 14px; color: #94A3B8; }}
            .qr-box {{ text-align: center; background: rgba(255,255,255,0.05); padding: 30px; border-radius: 12px; margin: 20px 0; }}
            .qr-code {{ font-family: monospace; font-size: 16px; color: #F59E0B; word-break: break-all; }}
            .content {{ padding: 30px 0; }}
            .button {{ display: inline-block; padding: 12px 30px; background: linear-gradient(135deg, #F59E0B, #D97706); color: #0A1628; text-decoration: none; border-radius: 8px; font-weight: 600; }}
            .footer {{ text-align: center; padding-top: 30px; border-top: 1px solid rgba(255,255,255,0.1); font-size: 12px; color: #64748B; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="title">eSIMNest</div>
                <div class="subtitle">Global Data eSIM</div>
                <div style="font-size: 12px; color: #64748B;">A Tech Talk Titans Product</div>
            </div>
            <div class="content">
                <h2>Your eSIM for {country} is Ready! 📱</h2>
                <p>Hi {name},</p>
                <p>Great news! Your eSIM for <strong>{country}</strong> is ready to install.</p>
                
                <div class="qr-box">
                    <p><strong>Plan Details:</strong></p>
                    <p>📶 {plan}</p>
                    <p>⏳ Expires: {expiry_date.strftime('%d %B %Y')}</p>
                </div>
                
                <div class="qr-box">
                    <p><strong>📋 Scan this QR Code:</strong></p>
                    <div style="background: white; padding: 20px; display: inline-block; border-radius: 8px;">
                        <img src="{qr_code}" alt="QR Code" style="width: 150px; height: 150px;">
                    </div>
                </div>
                
                <div class="qr-box">
                    <p><strong>🔑 Activation Code (Manual Entry):</strong></p>
                    <div class="qr-code">{activation_code}</div>
                </div>
                
                <br>
                <center><a href="https://esmnst-frontend.onrender.com/esims" class="button">View My eSIMs</a></center>
                
                <br>
                <p><strong>How to install:</strong></p>
                <ol>
                    <li>Go to Settings → Mobile Network</li>
                    <li>Tap "Add eSIM" or "Download eSIM"</li>
                    <li>Scan the QR code above</li>
                    <li>Follow the prompts to complete installation</li>
                </ol>
                
                <p>Safe travels!</p>
            </div>
            <div class="footer">
                <div>© 2026 eSIMNest. A Tech Talk Titans Product</div>
                <div>support@esimnest.com | www.esimnest.com</div>
            </div>
        </div>
    </body>
    </html>"""

# =====================================================
# 15. PAYMENT GATEWAY HELPERS (Simplified)
# =====================================================

def create_razorpay_order(amount: float, currency: str = 'USD'):
    return {
        'id': 'order_' + secrets.token_hex(8),
        'amount': int(amount * 100),
        'currency': currency
    }

def create_paypal_order(amount: float, currency: str = 'USD'):
    return {
        'id': 'PAY-' + secrets.token_hex(8),
        'amount': amount,
        'currency': currency
    }

def verify_razorpay_payment(data: dict):
    return True

def verify_paypal_payment(data: dict):
    return True

# =====================================================
# 16. HEALTH CHECK
# =====================================================

@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "eSIMNest API",
        "version": "1.0.0",
        "brand": "eSIMNest",
        "slogan": "Global Data eSIM",
        "company": "Tech Talk Titans"
    }

# =====================================================
# TEST ENDPOINT - To verify backend is working
# =====================================================

@app.get("/api/test")
async def test_endpoint():
    """Simple test endpoint to verify backend is running"""
    return {
        "status": "ok",
        "message": "Backend is working!",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/esim/test")
async def test_esim_endpoint():
    """Test eSIM endpoint without auth"""
    return {
        "status": "ok",
        "message": "eSIM endpoint is reachable",
        "esim_access_code_set": bool(ESIM_ACCESS_CODE)
        # ✅ Removed esim_secret_key_set
    }


# =====================================================
# 17. RUN
# =====================================================

# =====================================================
# TEST: List all registered routes
# =====================================================

@app.get("/api/routes")
async def list_routes():
    """List all registered routes for debugging"""
    routes = []
    for route in app.routes:
        routes.append({
            "path": route.path,
            "methods": [m for m in route.methods] if hasattr(route, 'methods') else []
        })
    return {"routes": routes}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
