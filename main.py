# =====================================================
# eSIMNest - Global Data eSIM
# A Tech Talk Titans Product
# Backend API - FastAPI
# =====================================================

from fastapi import FastAPI, HTTPException, Depends, Header
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
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

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
    allow_origins=["*"],  # Update with your domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =====================================================
# 2. FIREBASE INITIALIZATION
# =====================================================

# Initialize Firebase Admin SDK
# You'll need to download your service account key from Firebase Console
# Settings > Service Accounts > Generate New Private Key
# Save it as service-account.json in your backend folder

try:
    # Use environment variable for production
    if os.getenv('FIREBASE_CREDENTIALS'):
        cred = credentials.Certificate(json.loads(os.getenv('FIREBASE_CREDENTIALS')))
    else:
        # Use local file for development
        cred = credentials.Certificate("service-account.json")
    
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase initialized successfully")
except Exception as e:
    print(f"❌ Firebase initialization error: {e}")

# =====================================================
# 3. PROVIDER API CONFIGURATION (eSIM.tech)
# =====================================================

PROVIDER_API_KEY = os.getenv('PROVIDER_API_KEY', 'your-api-key-here')
PROVIDER_API_URL = os.getenv('PROVIDER_API_URL', 'https://api.esim.tech/v1')
MARKUP_MULTIPLIER = 2  # Double the price

# =====================================================
# 4. PYDANTIC MODELS (Data Validation)
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

class PlanResponse(BaseModel):
    id: str
    country: str
    data: str
    validity: str
    price: float  # Retail price (doubled)
    currency: str
    plan_type: str

# =====================================================
# 5. AUTHENTICATION HELPERS
# =====================================================

async def get_current_user(authorization: str = Header(...)):
    """Verify Firebase ID token and return user data"""
    try:
        # Extract token from Bearer header
        token = authorization.split(' ')[1]
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid authentication")

def create_user_document(uid: str, user_data: dict):
    """Create user document in Firestore"""
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
    """Generate unique referral code"""
    return secrets.token_hex(4).upper()

# =====================================================
# 6. AUTHENTICATION ENDPOINTS
# =====================================================

@app.post("/api/auth/register")
async def register_user(user_data: UserRegister):
    """Register a new user"""
    try:
        # Create user in Firebase Auth
        user = auth.create_user(
            email=user_data.email,
            password=user_data.password,
            display_name=user_data.displayName,
            phone_number=user_data.phone
        )
        
        # Create user document in Firestore
        create_user_document(user.uid, user_data.dict())
        
        # Send welcome email via Firestore trigger
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
    """Verify Firebase ID token"""
    return {
        "success": True,
        "user": {
            "uid": user['uid'],
            "email": user.get('email'),
            "name": user.get('name', '')
        }
    }

# =====================================================
# 7. USER ENDPOINTS
# =====================================================

@app.get("/api/user/profile")
async def get_user_profile(user: dict = Depends(get_current_user)):
    """Get user profile data"""
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
    """Update user profile"""
    try:
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        
        # Remove fields that shouldn't be updated
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
    """Get dashboard statistics"""
    try:
        uid = user['uid']
        
        # Get user data
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_data = user_doc.to_dict()
        
        # Get active eSIMs count
        esims_ref = db.collection('esims').where('userId', '==', uid).where('status', '==', 'active')
        active_esims = esims_ref.get()
        
        # Get orders count
        orders_ref = db.collection('orders').where('userId', '==', uid)
        total_orders = orders_ref.get()
        
        # Get recent orders
        recent_orders_ref = db.collection('orders').where('userId', '==', uid).order_by('createdAt', direction=firestore.Query.DESCENDING).limit(5)
        recent_orders = recent_orders_ref.get()
        
        # Get active eSIMs
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
# 8. WALLET ENDPOINTS
# =====================================================

@app.get("/api/wallet/balance")
async def get_wallet_balance(user: dict = Depends(get_current_user)):
    """Get user wallet balance"""
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
    """Add money to wallet via payment gateway"""
    try:
        uid = user['uid']
        
        # Create payment request in Firestore
        payment_ref = db.collection('paymentRequests').add({
            'userId': uid,
            'method': request.method,
            'amount': request.amount,
            'currency': request.currency,
            'status': 'pending',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        if request.method == 'razorpay':
            # Create Razorpay order (simplified)
            razorpay_response = create_razorpay_order(request.amount, request.currency)
            return {
                "success": True,
                "payment_id": payment_ref[1].id,
                "razorpay_order_id": razorpay_response.get('id'),
                "amount": request.amount,
                "currency": request.currency
            }
        elif request.method == 'paypal':
            # Create PayPal order (simplified)
            paypal_response = create_paypal_order(request.amount, request.currency)
            return {
                "success": True,
                "payment_id": payment_ref[1].id,
                "paypal_order_id": paypal_response.get('id'),
                "amount": request.amount,
                "currency": request.currency
            }
        else:
            # Manual payment
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
    """Verify payment and credit wallet"""
    try:
        uid = user['uid']
        payment_id = payment_data.get('payment_id')
        payment_method = payment_data.get('method')
        
        # Verify payment with gateway
        verified = False
        if payment_method == 'razorpay':
            verified = verify_razorpay_payment(payment_data)
        elif payment_method == 'paypal':
            verified = verify_paypal_payment(payment_data)
        
        if not verified:
            raise HTTPException(status_code=400, detail="Payment verification failed")
        
        # Get payment request
        payment_ref = db.collection('paymentRequests').document(payment_id)
        payment_doc = payment_ref.get()
        
        if not payment_doc.exists:
            raise HTTPException(status_code=404, detail="Payment not found")
        
        payment_data = payment_doc.to_dict()
        
        # Credit wallet
        amount = payment_data.get('amount', 0)
        user_ref = db.collection('users').document(uid)
        
        # Update wallet balance
        user_ref.update({
            'walletBalance': firestore.Increment(amount)
        })
        
        # Create transaction record
        transaction_ref = db.collection('transactions').add({
            'userId': uid,
            'type': 'credit',
            'amount': amount,
            'currency': payment_data.get('currency', 'USD'),
            'description': f'Added money via {payment_method}',
            'reference': payment_data.get('reference', ''),
            'status': 'completed',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # Send email notification via Firestore
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
    """Get transaction history"""
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
# 9. eSIM ENDPOINTS
# =====================================================

@app.get("/api/esim/countries")
async def get_countries(user: dict = Depends(get_current_user)):
    """Get all available countries"""
    try:
        # Fetch from provider API
        response = requests.get(
            f"{PROVIDER_API_URL}/countries",
            headers={"Authorization": f"Bearer {PROVIDER_API_KEY}"}
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            # Fallback to Firestore
            countries_ref = db.collection('countries').where('active', '==', True)
            countries_docs = countries_ref.get()
            return [doc.to_dict() for doc in countries_docs]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/esim/plans")
async def get_plans(
    country: Optional[str] = None,
    user: dict = Depends(get_current_user)
):
    """Get eSIM plans with doubled prices"""
    try:
        # Fetch plans from provider API
        if country:
            response = requests.get(
                f"{PROVIDER_API_URL}/plans?country={country}",
                headers={"Authorization": f"Bearer {PROVIDER_API_KEY}"}
            )
        else:
            response = requests.get(
                f"{PROVIDER_API_URL}/plans",
                headers={"Authorization": f"Bearer {PROVIDER_API_KEY}"}
            )
        
        if response.status_code == 200:
            plans = response.json()
            
            # 🏷️ Double the price for each plan
            for plan in plans:
                wholesale_price = plan.get('price', 0)
                plan['price'] = wholesale_price * MARKUP_MULTIPLIER  # Hide wholesale
                plan['wholesale'] = None  # Remove wholesale from response
                plan['markup'] = MARKUP_MULTIPLIER
            
            return plans
        else:
            # Fallback to Firestore
            plans_ref = db.collection('plans')
            if country:
                plans_ref = plans_ref.where('country', '==', country)
            plans_ref = plans_ref.where('active', '==', True)
            plans_docs = plans_ref.get()
            
            return [doc.to_dict() for doc in plans_docs]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/esim/purchase")
async def purchase_esim(purchase: PurchasePlan, user: dict = Depends(get_current_user)):
    """Purchase an eSIM plan"""
    try:
        uid = user['uid']
        plan_id = purchase.plan_id
        country = purchase.country
        
        # Get user data
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_data = user_doc.to_dict()
        balance = user_data.get('walletBalance', 0)
        
        # Get plan price (fetch from provider or Firestore)
        plan_response = requests.get(
            f"{PROVIDER_API_URL}/plans/{plan_id}",
            headers={"Authorization": f"Bearer {PROVIDER_API_KEY}"}
        )
        
        if plan_response.status_code != 200:
            raise HTTPException(status_code=400, detail="Plan not found")
        
        plan_data = plan_response.json()
        wholesale_price = plan_data.get('price', 0)
        retail_price = wholesale_price * MARKUP_MULTIPLIER
        
        # Check wallet balance
        if balance < retail_price:
            raise HTTPException(status_code=400, detail="Insufficient wallet balance")
        
        # Debit wallet
        user_ref.update({
            'walletBalance': firestore.Increment(-retail_price)
        })
        
        # Create transaction
        transaction_ref = db.collection('transactions').add({
            'userId': uid,
            'type': 'debit',
            'amount': retail_price,
            'currency': 'USD',
            'description': f'Purchased eSIM for {country} - {plan_data.get("name", "Plan")}',
            'reference': plan_id,
            'status': 'completed',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # Create order
        order_ref = db.collection('orders').add({
            'userId': uid,
            'country': country,
            'plan': {
                'id': plan_id,
                'name': plan_data.get('name', ''),
                'data': plan_data.get('data', ''),
                'validity': plan_data.get('validity', '')
            },
            'amount': retail_price,
            'currency': 'USD',
            'status': 'pending',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # 🚀 Purchase eSIM from provider
        try:
            purchase_response = requests.post(
                f"{PROVIDER_API_URL}/purchase",
                headers={"Authorization": f"Bearer {PROVIDER_API_KEY}"},
                json={
                    "plan_id": plan_id,
                    "country": country,
                    "user_reference": uid
                }
            )
            
            if purchase_response.status_code == 200:
                esim_data = purchase_response.json()
                # Store eSIM details
                esim_ref = db.collection('esims').add({
                    'userId': uid,
                    'orderId': order_ref[1].id,
                    'country': country,
                    'plan': plan_data.get('name', ''),
                    'iccid': esim_data.get('iccid', ''),
                    'phoneNumber': esim_data.get('phoneNumber', ''),
                    'qrCode': esim_data.get('qrCode', ''),
                    'activationCode': esim_data.get('activationCode', ''),
                    'status': 'active',
                    'activationDate': datetime.now(),
                    'expiryDate': datetime.now() + timedelta(days=int(plan_data.get('validity', 7))),
                    'createdAt': firestore.SERVER_TIMESTAMP
                })
                
                # Update order status
                db.collection('orders').document(order_ref[1].id).update({
                    'status': 'delivered',
                    'esimId': esim_ref[1].id,
                    'deliveredAt': firestore.SERVER_TIMESTAMP
                })
                
                # 📧 Send eSIM delivery email via Firestore trigger
                send_email_trigger(
                    to=user_data.get('email'),
                    subject=f"Your eSIM for {country} is Ready! 📱",
                    html=esim_delivery_email(
                        user_data.get('displayName', 'Traveler'),
                        country,
                        plan_data.get('name', 'Plan'),
                        esim_data.get('qrCode', ''),
                        esim_data.get('activationCode', ''),
                        datetime.now() + timedelta(days=int(plan_data.get('validity', 7)))
                    )
                )
                
                return {
                    "success": True,
                    "order_id": order_ref[1].id,
                    "esim": {
                        "iccid": esim_data.get('iccid', ''),
                        "phoneNumber": esim_data.get('phoneNumber', ''),
                        "qrCode": esim_data.get('qrCode', ''),
                        "activationCode": esim_data.get('activationCode', '')
                    }
                }
            else:
                # Purchase failed - refund wallet
                user_ref.update({
                    'walletBalance': firestore.Increment(retail_price)
                })
                db.collection('orders').document(order_ref[1].id).update({
                    'status': 'failed'
                })
                raise HTTPException(status_code=400, detail="Failed to purchase eSIM from provider")
        except Exception as e:
            # Error - refund wallet
            user_ref.update({
                'walletBalance': firestore.Increment(retail_price)
            })
            db.collection('orders').document(order_ref[1].id).update({
                'status': 'failed'
            })
            raise HTTPException(status_code=400, detail=f"Provider error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/esim/active")
async def get_active_esims(user: dict = Depends(get_current_user)):
    """Get user's active eSIMs"""
    try:
        uid = user['uid']
        esims_ref = db.collection('esims').where('userId', '==', uid).where('status', '==', 'active')
        esims_docs = esims_ref.get()
        
        return [doc.to_dict() for doc in esims_docs]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/esim/orders")
async def get_orders(user: dict = Depends(get_current_user)):
    """Get user's orders"""
    try:
        uid = user['uid']
        orders_ref = db.collection('orders').where('userId', '==', uid).order_by('createdAt', direction=firestore.Query.DESCENDING)
        orders_docs = orders_ref.get()
        
        return [doc.to_dict() for doc in orders_docs]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# =====================================================
# 10. ADMIN ENDPOINTS
# =====================================================

@app.get("/api/admin/dashboard")
async def admin_dashboard(user: dict = Depends(get_current_user)):
    """Admin dashboard statistics"""
    try:
        # Check if user is admin
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists or user_doc.to_dict().get('role') != 'admin':
            raise HTTPException(status_code=403, detail="Admin access required")
        
        # Get statistics
        users = db.collection('users').get()
        orders = db.collection('orders').get()
        pending_orders = db.collection('orders').where('status', '==', 'pending').get()
        delivered_orders = db.collection('orders').where('status', '==', 'delivered').get()
        esims = db.collection('esims').get()
        payments = db.collection('paymentRequests').where('status', '==', 'pending').get()
        
        # Calculate revenue
        total_revenue = 0
        for order in orders:
            total_revenue += order.to_dict().get('amount', 0)
        
        return {
            "totalUsers": len(users),
            "totalOrders": len(orders),
            "pendingOrders": len(pending_orders),
            "deliveredOrders": len(delivered_orders),
            "totalEsims": len(esims),
            "totalRevenue": total_revenue,
            "pendingPayments": len(payments)
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/admin/users")
async def get_all_users(user: dict = Depends(get_current_user)):
    """Get all users (admin only)"""
    try:
        # Check if user is admin
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
    """Get all payment requests (admin only)"""
    try:
        # Check if user is admin
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
    """Verify manual payment (admin only)"""
    try:
        # Check if user is admin
        uid = user['uid']
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        
        if not user_doc.exists or user_doc.to_dict().get('role') != 'admin':
            raise HTTPException(status_code=403, detail="Admin access required")
        
        payment_id = data.get('payment_id')
        status = data.get('status')  # 'approved' or 'rejected'
        
        payment_ref = db.collection('paymentRequests').document(payment_id)
        payment_doc = payment_ref.get()
        
        if not payment_doc.exists:
            raise HTTPException(status_code=404, detail="Payment not found")
        
        payment_data = payment_doc.to_dict()
        
        if status == 'approved':
            # Credit wallet
            amount = payment_data.get('amount', 0)
            user_id = payment_data.get('userId')
            
            user_ref = db.collection('users').document(user_id)
            user_ref.update({
                'walletBalance': firestore.Increment(amount)
            })
            
            # Create transaction
            db.collection('transactions').add({
                'userId': user_id,
                'type': 'credit',
                'amount': amount,
                'currency': payment_data.get('currency', 'USD'),
                'description': f'Manual payment approved by admin',
                'reference': payment_id,
                'status': 'completed',
                'createdAt': firestore.SERVER_TIMESTAMP
            })
        
        # Update payment request
        payment_ref.update({
            'status': status,
            'verifiedAt': firestore.SERVER_TIMESTAMP,
            'verifiedBy': uid
        })
        
        return {"success": True, "message": f"Payment {status}"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# =====================================================
# 11. EMAIL FUNCTIONS (Firestore Trigger)
# =====================================================

def send_email_trigger(to: str, subject: str, html: str):
    """Add email to Firestore for Trigger Email extension"""
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
# 12. EMAIL TEMPLATES
# =====================================================

def welcome_email_template(name: str):
    return f"""
    <!DOCTYPE html>
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
            .brand {{ color: #F59E0B; }}
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
                <center><a href="#" class="button">Explore eSIMs</a></center>
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
    </html>
    """

def payment_confirmation_email(name: str, amount: float, method: str):
    return f"""
    <!DOCTYPE html>
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
                <center><a href="#" class="button">View Wallet</a></center>
                <br>
                <p>Safe travels!</p>
            </div>
            <div class="footer">
                <div>© 2026 eSIMNest. A Tech Talk Titans Product</div>
                <div>support@esimnest.com | www.esimnest.com</div>
            </div>
        </div>
    </body>
    </html>
    """

def esim_delivery_email(name: str, country: str, plan: str, qr_code: str, activation_code: str, expiry_date):
    return f"""
    <!DOCTYPE html>
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
                        <!-- In production, this would be an actual QR code image -->
                        <div style="width: 150px; height: 150px; background: #000; margin: 0 auto; color: #fff; display: flex; align-items: center; justify-content: center; font-size: 10px; word-break: break-all; padding: 10px;">
                            {qr_code[:50]}...
                        </div>
                    </div>
                </div>
                
                <div class="qr-box">
                    <p><strong>🔑 Activation Code (Manual Entry):</strong></p>
                    <div class="qr-code">{activation_code}</div>
                </div>
                
                <br>
                <center><a href="#" class="button">View My eSIMs</a></center>
                
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
    </html>
    """

# =====================================================
# 13. PAYMENT GATEWAY HELPERS (Simplified)
# =====================================================

def create_razorpay_order(amount: float, currency: str = 'USD'):
    """Create a Razorpay order"""
    # In production, implement actual Razorpay API call
    return {
        'id': 'order_' + secrets.token_hex(8),
        'amount': int(amount * 100),
        'currency': currency
    }

def create_paypal_order(amount: float, currency: str = 'USD'):
    """Create a PayPal order"""
    # In production, implement actual PayPal API call
    return {
        'id': 'PAY-' + secrets.token_hex(8),
        'amount': amount,
        'currency': currency
    }

def verify_razorpay_payment(data: dict):
    """Verify Razorpay payment signature"""
    # In production, implement actual verification
    return True

def verify_paypal_payment(data: dict):
    """Verify PayPal payment"""
    # In production, implement actual verification
    return True

# =====================================================
# 14. HEALTH CHECK
# =====================================================

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

# =====================================================
# 15. RUN
# =====================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
