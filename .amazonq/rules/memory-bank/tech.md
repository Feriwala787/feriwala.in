# Technology Stack

## Programming Languages

### Backend
- **Node.js** - Runtime environment
- **JavaScript** (ES6+) - Primary language

### Frontend
- **JavaScript** (React.js) - Admin portal
- **Dart** - Flutter mobile apps

## Frameworks & Libraries

### Backend (Node.js)
- **express** ^4.18.2 - Web framework
- **socket.io** ^4.7.2 - Real-time communication
- **mongoose** ^8.0.3 - MongoDB ODM
- **sequelize** ^6.35.2 - PostgreSQL ORM
- **jsonwebtoken** ^9.0.2 - JWT authentication
- **bcryptjs** ^2.4.3 - Password hashing
- **express-validator** ^7.0.1 - Input validation
- **express-rate-limit** ^7.1.4 - Rate limiting
- **helmet** ^7.1.0 - Security headers
- **cors** ^2.8.5 - CORS handling
- **multer** ^1.4.5-lts.1 - File uploads
- **multer-s3** ^3.0.1 - S3 uploads
- **@aws-sdk/client-s3** ^3.1036.0 - AWS S3 client
- **sharp** ^0.33.1 - Image processing
- **@google/generative-ai** ^0.24.1 - AI integration
- **axios** ^1.6.2 - HTTP client
- **morgan** ^1.10.0 - HTTP logging
- **uuid** ^9.0.0 - UUID generation

### Admin Portal (React.js)
- **react** ^18.2.0 - UI library
- **react-dom** ^18.2.0 - DOM rendering
- **react-router-dom** ^6.21.0 - Routing
- **axios** ^1.6.2 - HTTP client
- **@headlessui/react** ^1.7.17 - Unstyled UI components
- **@heroicons/react** ^2.1.1 - Icon library
- **react-hot-toast** ^2.4.1 - Notifications
- **react-hook-form** ^7.49.2 - Form handling
- **recharts** ^2.10.3 - Charts and analytics
- **date-fns** ^3.0.6 - Date utilities
- **tailwindcss** ^3.4.0 - CSS framework

### Flutter Apps
- **Flutter SDK** >=3.0.0 <4.0.0
- **http** ^1.1.0 - HTTP client
- **provider** ^6.1.1 - State management
- **shared_preferences** ^2.2.2 - Local storage
- **geolocator** ^10.1.0 - Location services
- **permission_handler** ^11.3.1 - Permissions
- **socket_io_client** ^2.0.3+1 - WebSocket client
- **amazon_location_flutter** ^0.1.0 - AWS Location Service
- **cached_network_image** ^3.3.0 - Image caching
- **flutter_rating_bar** ^4.0.1 - Rating UI
- **shimmer** ^3.0.0 - Loading placeholders
- **intl** ^0.19.0 - Internationalization
- **url_launcher** ^6.2.2 - External URLs

## Databases

### MongoDB (Atlas Free Tier)
- User accounts and authentication
- Session management
- User profiles

### PostgreSQL
- Product catalog
- Orders and transactions
- Inventory management
- Shop data

## External Services

### AWS Services
- **AWS Lightsail** - Server hosting (ap-south-1)
- **AWS S3** - File storage (via @aws-sdk/client-s3)
- **AWS Location Service** - Maps (via amazon_location_flutter)

### Google Services
- **Google Maps API** - Location and mapping
- **Google Generative AI** - AI features

## Development Tools

### Backend
```bash
npm run dev          # Start with nodemon (hot reload)
npm start            # Production start
npm run migrate      # Run database migrations
npm run seed         # Seed database
npm test             # Run smoke + health tests
npm run test:api     # Run API integration tests
npm run test:all     # Run all tests
npm run smoke        # Syntax check
```

### Admin Portal
```bash
npm start            # Development server
npm run build        # Production build
```

### Flutter Apps
```bash
flutter run          # Run in debug mode
flutter build apk    # Build debug APK
flutter build apk --release  # Build release APK
flutter test         # Run tests
```

## Build Systems

### Backend
- **npm** - Package manager
- **nodemon** ^3.0.2 - Development auto-reload

### Admin Portal
- **npm** - Package manager
- **react-scripts** 5.0.1 - Build tooling
- **postcss** ^8.4.32 - CSS processing
- **autoprefixer** ^10.4.16 - CSS vendor prefixes

### Flutter Apps
- **Gradle** - Android build system
- **flutter_launcher_icons** ^0.13.1 - Icon generation
- **flutter_lints** ^3.0.1 - Linting

## Deployment

### Process Management
- **PM2** - Node.js process manager (ecosystem.config.js)

### Web Servers
- **Nginx** - Reverse proxy (nginx.conf)
- **Apache** - Alternative proxy (apache-proxy.conf)

### CI/CD
- **GitHub Actions** - Automated builds and deployments
  - APK builds for Flutter apps
  - Backend deployment
  - Admin portal deployment
  - Automated testing

## Server Details
- **Instance**: Node-js-1 (AWS Lightsail)
- **Region**: ap-south-1 (Mumbai)
- **IPv4**: 65.2.9.216
- **IPv6**: 2406:da1a:19e:d100:a0e2:d3b3:4b57:29ef

## Environment Requirements
- Node.js (for backend and admin portal)
- Flutter SDK >=3.0.0
- MongoDB connection (Atlas)
- PostgreSQL database
- AWS credentials (S3, Location Service)
- Google Maps API key
- Google Generative AI API key
