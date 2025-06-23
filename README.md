# Revive and Thrive Community Share App

A Flutter application for community sharing and borrowing of items.

## Security Notice for API Keys

This project uses Firebase and Google Sign-In services that require API keys. To protect these keys:

1. We use environment variables stored in a `.env` file
2. The `.env` file is excluded from version control in `.gitignore`
3. A template file (`.env.template`) is provided without actual keys

## Setting Up Environment Variables

To set up your environment variables:

1. Run the setup script:
   ```bash
   ./setup_env.sh
   ```

2. Edit the newly created `.env` file with your actual API keys and configuration values:
   ```
   # Firebase Configuration
   FIREBASE_WEB_API_KEY=your_web_api_key
   FIREBASE_ANDROID_API_KEY=your_android_api_key
   FIREBASE_IOS_API_KEY=your_ios_api_key
   FIREBASE_MACOS_API_KEY=your_macos_api_key
   FIREBASE_WINDOWS_API_KEY=your_windows_api_key

   FIREBASE_PROJECT_ID=your_project_id
   FIREBASE_AUTH_DOMAIN=your_auth_domain
   FIREBASE_STORAGE_BUCKET=your_storage_bucket
   FIREBASE_MESSAGING_SENDER_ID=your_messaging_sender_id

   FIREBASE_WEB_APP_ID=your_web_app_id
   FIREBASE_ANDROID_APP_ID=your_android_app_id
   FIREBASE_IOS_APP_ID=your_ios_app_id
   FIREBASE_MACOS_APP_ID=your_macos_app_id
   FIREBASE_WINDOWS_APP_ID=your_windows_app_id

   # Google Sign-In
   GOOGLE_SIGNIN_CLIENT_ID=your_google_signin_client_id
   ```

3. Install project dependencies:
   ```bash
   flutter pub get
   ```

4. Run the application:
   ```bash
   flutter run
   ```

## Important Security Practices

- **Never commit the `.env` file to version control**
- Always use the `AppConfig` class to access environment variables in code
- If you're sharing the project, share the `.env.template` file, not the actual `.env` file
- For CI/CD pipelines, set up secrets in your build environment

## Getting Started

This project is a Flutter application for community sharing and borrowing of items. Users can create accounts, list items they're willing to share, and borrow items from others in their community.

## Features

- User authentication with Firebase Auth and Google Sign-In
- Item listing and searching
- Category and subcategory navigation
- Borrowing request system
- Notifications for requests and approvals
