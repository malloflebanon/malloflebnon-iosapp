# Mall Of Lebanon iOS App

[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-14.0+-blue.svg)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-green.svg)](https://developer.apple.com/xcode/swiftui/)

A native iOS e-commerce application for Mall Of Lebanon, featuring a multi-vendor marketplace with product browsing, cart management, and secure checkout functionality.

## Features

### Core Functionality
- **Product Browsing**: Browse products by categories with filtering and sorting options
- **Search & Discovery**: Advanced search with real-time suggestions and filters
- **Product Details**: Comprehensive product information with image galleries, specifications, and reviews
- **Shopping Cart**: Add, remove, and manage products in cart with quantity controls
- **User Authentication**: Secure login and registration system with profile management
- **Multi-vendor Support**: Products from multiple sellers with seller profiles
- **Categories & Collections**: Organized product browsing with featured collections

### Technical Features
- **SwiftUI Architecture**: Modern declarative UI framework
- **MVVM Pattern**: Clean architecture with separation of concerns
- **Combine Framework**: Reactive programming for data binding and API calls
- **REST API Integration**: Full integration with Mall Of Lebanon backend API
- **Real-time Updates**: Live product data and inventory status
- **Pagination**: Efficient loading of large product catalogs
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Caching**: Optimized data loading and offline support

## Screenshots

[Add screenshots of the app here]

## Requirements

- **iOS 14.0+**
- **Xcode 13.0+**
- **Swift 5.5+**
- **Internet connection** for API connectivity

## Installation

### Prerequisites

1. **Xcode**: Download and install Xcode from the Mac App Store or Apple Developer Portal
2. **Git**: Ensure Git is installed on your macOS system
3. **Apple Developer Account** (for device testing and distribution)

### Clone and Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/malloflebanon/malloflebnon-iosapp.git
   cd malloflebnon-iosapp
   ```

2. **Open the project in Xcode:**
   ```bash
   open MallOfLebanon-iOS.xcodeproj
   ```

   Or launch Xcode and open the `.xcodeproj` file manually.

3. **Configure the project:**
   - Select your development team in the project settings
   - Update the bundle identifier if needed
   - Ensure deployment target is set to iOS 14.0+

4. **API Configuration:**
   - The app is configured to connect to the Mall Of Lebanon backend API
   - Update the `baseURL` in `APIService.swift` if connecting to a different environment:
   ```swift
   private let baseURL = "http://YOUR_API_URL:PORT/api"
   ```

5. **Build and Run:**
   - Select your target device or simulator
   - Press `Cmd + R` or click the "Run" button in Xcode
   - The app will build and launch on your selected device/simulator

## Project Structure

```
MallOfLebanon-iOS/
├── Models/                 # Data models and structures
│   ├── ProductModels.swift # Product, Category, Collection models
│   ├── UserModels.swift    # User and authentication models
│   └── CartModels.swift    # Shopping cart related models
├── Views/                  # SwiftUI views
│   ├── ContentView.swift   # Main app container
│   ├── ProductViews/       # Product browsing and details
│   ├── AuthViews/          # Login and registration
│   └── CartViews/          # Shopping cart interface
├── ViewModels/             # Business logic and state management
│   ├── ProductListViewModel.swift
│   ├── AuthViewModel.swift
│   └── CartViewModel.swift
├── Services/               # API and external services
│   ├── APIService.swift    # Main API service class
│   └── KeychainManager.swift # Secure token storage
├── Utilities/              # Helper classes and extensions
└── Resources/              # Assets, Info.plist, etc.
```

## API Integration

The app integrates with the Mall Of Lebanon backend API providing:

### Endpoints
- **Authentication**: `/auth/login`, `/auth/register`, `/auth/logout`
- **Products**: `/products/public`, `/products/{id}`, `/products/featured`
- **Categories**: `/categories`
- **Collections**: `/collections`
- **User Profile**: `/users/profile`
- **Reviews**: `/reviews`

### API Configuration
The API service is configured in `APIService.swift` with:
- Automatic authentication token management
- Comprehensive error handling
- JSON encoding/decoding with custom date formats
- Support for pagination and filtering

## Configuration

### Network Security
The app supports HTTP connections for development. The `Info.plist` includes:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### App Configuration
- **Bundle Identifier**: Update in Xcode project settings
- **Display Name**: "Mall Of Lebanon"
- **Version**: 1.0
- **Supported Orientations**: Portrait (iPhone), All orientations (iPad)

## Development

### Architecture
The app follows the **MVVM (Model-View-ViewModel)** architecture:
- **Models**: Data structures representing API responses
- **Views**: SwiftUI views for the user interface
- **ViewModels**: Business logic and state management using `@ObservableObject`

### Key Components
- **APIService**: Centralized API communication
- **ProductListViewModel**: Manages product data and filtering
- **AuthViewModel**: Handles user authentication
- **KeychainManager**: Secure storage for authentication tokens

### State Management
- Uses SwiftUI's `@State`, `@ObservableObject`, and `@Published` for reactive UI updates
- Combine framework for handling async operations
- Error handling with user-friendly messages

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Ensure Xcode version compatibility
   - Check Swift version requirements
   - Verify deployment target settings

2. **API Connection Issues**
   - Verify network connectivity
   - Check API endpoint URLs
   - Ensure backend server is running

3. **Authentication Problems**
   - Clear app data and retry
   - Check token storage in Keychain
   - Verify API credentials

### Debug Mode
Enable debug logging by modifying the API service to print detailed request/response information.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow Swift naming conventions
- Use SwiftUI best practices
- Maintain MVVM architecture
- Add appropriate comments for complex logic

## License

This project is proprietary software owned by Mall Of Lebanon. All rights reserved.

## Contact

**Mall Of Lebanon**
- Website: [https://malloflebanon.com](https://malloflebanon.com)
- Email: info@malloflebanon.com

## Version History

### v1.0 (Current)
- Initial release with core e-commerce functionality
- Product browsing and search
- User authentication
- Shopping cart management
- Multi-vendor support
- Category and collection browsing

---

**Built with ❤️ by the Mall Of Lebanon development team**