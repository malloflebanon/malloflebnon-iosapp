# Mall Of Lebanon - iOS Customer App

A native iOS shopping application for Mall Of Lebanon's multi-vendor e-commerce platform, designed specifically for customers/buyers.

## 🛍️ Overview

This iOS app provides a complete mobile shopping experience for Mall Of Lebanon customers, featuring:

- **Customer Authentication**: Native login and registration
- **Product Browsing**: Browse products from multiple vendors
- **Shopping Cart**: Add, remove, and manage cart items
- **Secure Checkout**: Complete purchases with various payment methods
- **Order Tracking**: Monitor order status and history
- **Account Management**: Update profile and preferences

## 📱 Features

### ✅ Implemented
- **Authentication System**:
  - Customer registration with form validation
  - Secure login with JWT token management
  - Keychain storage for sensitive data
  - Form validation with real-time feedback

- **Core Architecture**:
  - SwiftUI-based modern interface
  - MVVM pattern with Combine framework
  - Secure API integration with your backend
  - Shopping cart persistence
  - Tab-based navigation

### 🔄 Planned Features
- Product catalog with categories
- Search and filtering
- Product details with reviews
- Shopping cart and checkout
- Order history and tracking
- Push notifications
- Apple Pay integration
- Store locator with maps

## 🏗️ Architecture

### **Tech Stack**
- **Language**: Swift 5.0+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM + Combine
- **Networking**: URLSession
- **Storage**:
  - Keychain (secure token storage)
  - UserDefaults (user preferences)
  - Core Data (future: offline data)

### **Project Structure**
```
MallOfLebanon-iOS/
├── Models/                 # Data models
│   ├── User.swift         # User and authentication models
│   ├── Product.swift      # Product and catalog models
│   └── APIModels.swift    # API request/response models
├── Views/                 # SwiftUI views
│   ├── Authentication/   # Login and registration
│   ├── Shopping/         # Product browsing
│   ├── Cart/            # Shopping cart
│   ├── Account/         # User account
│   └── Store/           # Store locator
├── Services/             # Business logic
│   ├── APIService.swift         # Backend API client
│   ├── AuthenticationManager.swift # Auth management
│   └── CartManager.swift        # Cart management
├── Utilities/           # Helper classes
│   └── KeychainManager.swift   # Secure storage
└── Resources/           # Assets and config
```

## 🔌 Backend Integration

### **API Endpoints Used**
The app connects to your existing Mall Of Lebanon backend:

- **Base URL**: `http://localhost:3007/api`
- **Authentication**:
  - `POST /auth/register` - Customer registration
  - `POST /auth/login` - Customer login
  - `POST /auth/logout` - Session logout
  - `GET /users/profile` - User profile

- **Products** (Future):
  - `GET /products/public` - Browse products
  - `GET /products/featured` - Featured products
  - `GET /categories` - Product categories

- **Reviews** (Future):
  - `POST /reviews` - Submit product review
  - `GET /reviews/product/{id}` - Product reviews

### **Authentication Flow**
1. User enters credentials in native iOS forms
2. App sends request to your backend API
3. Backend validates and returns JWT token
4. Token stored securely in iOS Keychain
5. Token automatically included in subsequent requests
6. Auto-logout on token expiration

## 🚀 Getting Started

### **Requirements**
- Xcode 15.0+
- iOS 15.0+
- Mall Of Lebanon backend running on `localhost:3007`

### **Installation**
1. Open `MallOfLebanon-iOS.xcodeproj` in Xcode
2. Ensure your Mall Of Lebanon backend is running
3. Build and run the project
4. Test with existing customer accounts or create new ones

### **Configuration**
- **Backend URL**: Update in `APIService.swift` if needed
- **Bundle Identifier**: `com.malloflebanon.ios`
- **Display Name**: "Mall Of Lebanon"

## 🔐 Security Features

- **JWT Token Storage**: Secure keychain storage
- **Network Security**: HTTPS enforcement (configurable)
- **Input Validation**: Client-side form validation
- **Auto-Logout**: Automatic logout on token expiration
- **Secure Fields**: Password fields with visibility toggle

## 📋 User Journey

### **First-Time User**
1. Download and open app
2. See welcome screen with branding
3. Choose "Create Account"
4. Fill registration form (buyer role)
5. Automatic login after registration
6. Access main shopping interface

### **Returning User**
1. Open app
2. Automatic login if authenticated
3. Or login with saved credentials
4. Access shopping features immediately

## 🎨 Design Guidelines

- **Colors**: Blue accent color matching Mall Of Lebanon brand
- **Typography**: iOS system fonts for readability
- **Navigation**: Tab-based with badges for cart count
- **Forms**: Native iOS form elements with validation
- **Loading States**: Progress indicators for network calls
- **Error Handling**: User-friendly error messages

## 🧪 Testing

### **Manual Testing**
1. **Registration**: Create new customer account
2. **Login**: Test with existing credentials
3. **Validation**: Test form validation messages
4. **Navigation**: Test tab switching and flow
5. **Error Handling**: Test with network issues

### **API Testing**
Ensure your backend APIs are working:
```bash
# Test registration
curl -X POST http://localhost:3007/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password","firstName":"Test","lastName":"User","role":"buyer"}'

# Test login
curl -X POST http://localhost:3007/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'
```

## 🚧 Development Roadmap

### **Phase 1** ✅ - Authentication (Complete)
- [x] User registration and login
- [x] JWT token management
- [x] Form validation
- [x] Secure storage

### **Phase 2** 🔄 - Shopping Experience
- [ ] Product catalog browsing
- [ ] Category navigation
- [ ] Search functionality
- [ ] Product details view

### **Phase 3** 📅 - Cart & Checkout
- [ ] Shopping cart management
- [ ] Checkout flow
- [ ] Payment integration
- [ ] Order confirmation

### **Phase 4** 🔮 - Advanced Features
- [ ] Order history
- [ ] Push notifications
- [ ] Apple Pay integration
- [ ] Store locator with maps
- [ ] Customer reviews

## 🔄 Multi-Vendor Integration

The app is designed to work with your multi-vendor system:

- **Role**: All registrations default to `"buyer"` role
- **Seller Integration**: Ready for future seller features
- **Commission System**: Backend handles vendor commissions
- **Order Splitting**: Backend manages multi-vendor orders
- **Store Fronts**: Ready to display vendor stores

## 📞 Support

For development questions or issues:
1. Check your backend API is running on `localhost:3007`
2. Verify API endpoints match your backend implementation
3. Test authentication with your existing web frontend
4. Check Xcode console for detailed error messages

## 📄 License

This iOS app is part of the Mall Of Lebanon project.

---

**Ready for shopping! 🛍️**

*Built with ❤️ using SwiftUI for Mall Of Lebanon customers*