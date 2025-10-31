# قاموس (Kamoos) - Arabic Dictionary App

A modern, feature-rich Arabic dictionary application built with Flutter, designed to provide comprehensive word meanings from multiple sources with AI-powered definitions.

## 📱 Features

### 📚 Multiple Dictionary Sources
- **Al-Mu'jam al-Wasit** (المعجم الوسيط) - Comprehensive Arabic dictionary
- **Al-Mawrid** (المورد) - Arabic-English dictionary
- **Lisan al-Arab** (لسان العرب) - Classical Arabic dictionary
- **Gharib al-Quran** (غريب القرآن) - Quranic vocabulary
- **Taj al-Arus** (تاج العروس) - Classical Arabic lexicon
- **Custom AI-powered definitions** using Google Gemini

### 🎨 Modern UI/UX
- **Material 3 Design** with dark/light theme support
- **Minimalistic and clean interface**
- **RTL (Right-to-Left) support** for Arabic text
- **Smooth animations** and transitions
- **Responsive design** for all screen sizes

### 🔍 Smart Search
- **Real-time search suggestions**
- **Dictionary filtering** by source
- **Fast local database** queries
- **AI fallback** for words not found in dictionaries

### 🤖 AI Integration
- **Google Gemini API** for enhanced word definitions
- **Comprehensive meanings** in Arabic, English, and Urdu
- **Etymology and historical context**
- **Usage examples** from Quran, Hadith, and classical poetry
- **Related words and derivatives**

### 🌐 Multi-language Support
- **Arabic** (primary interface and content)
- **English** translations and definitions
- **Urdu** translations (Nastaliq script)

## 📸 Screenshots

<div align="center">
  <img src="assets/screenshots/home_screen.png" alt="Home Screen" width="200"/>
  <img src="assets/screenshots/search_results.png" alt="Search Results" width="200"/>
  <img src="assets/screenshots/word_details.png" alt="Word Details" width="200"/>
  <img src="assets/screenshots/dark_mode.png" alt="Dark Mode" width="200"/>
</div>

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>= 3.0.0)
- Dart SDK (>= 2.17.0)
- Android Studio / VS Code with Flutter extension
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/HASHIM-HAMEEM/kamoosApp.git
   cd kamoosApp
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up API key**
   - Copy `.env.example` to `.env`
   - Add your Google Gemini API key:
     ```
     GEMINI_API_KEY=your_actual_api_key_here
     ```
   - Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)

4. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Build & Deploy

### Debug Build
```bash
flutter run --debug
```

### Release Build (Android)
```bash
flutter build apk --release
```

### Release Build (iOS)
```bash
flutter build ios --release
```

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/                  # UI screens
│   ├── search_screen.dart    # Main search interface
│   └── word_detail_screen.dart # Word details view
├── services/                 # Business logic
│   ├── api_service.dart      # Gemini API integration
│   ├── database_service.dart # Local database management
│   └── search_service.dart   # Search orchestration
├── widgets/                  # Reusable UI components
│   ├── word_card.dart        # Word result card
│   └── animated_splash_screen.dart # Custom splash screen
└── models/                   # Data models
    └── word.dart             # Word data structure
```

## 🗄️ Database

The app uses SQLite for local storage with pre-loaded dictionary data:
- **Size**: ~50MB compressed
- **Sources**: Multiple classical and modern Arabic dictionaries
- **Search**: Full-text search with Arabic morphology support
- **Updates**: Database can be updated without app updates

## 🔧 Configuration

### Environment Variables
Create a `.env` file in the root directory:
```env
GEMINI_API_KEY=your_gemini_api_key_here
```

### Supported Models
- **Primary**: `gemini-2.5-flash` (recommended)
- **Fallback**: `gemini-1.5-flash`

### API Configuration
- **Max Output Tokens**: 2048
- **Temperature**: 0.1 (for consistent results)
- **Timeout**: 30 seconds
- **Retry Logic**: Exponential backoff with 3 attempts

## 🎨 Customization

### Theme Colors
The app uses Material 3 theming with customizable colors:
```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: Color(0xFF1A1A1A),
  brightness: Brightness.light,
  // ... other colors
)
```

### Fonts
- **Primary**: Jameel Noori Nastaleeq (Urdu/Arabic)
- **Secondary**: System fonts (English)

### Logo & Branding
Replace assets in `assets/logo/`:
- `DLogo.png` - Main app logo
- Launcher icons and splash screen will be automatically generated

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 API Documentation

### Google Gemini Integration
The app integrates with Google Gemini for AI-powered definitions:

```dart
final apiService = ApiService(apiKey: 'your_api_key');
final word = await apiService.getWordMeaning('كلمة');
```

### Response Format
```json
{
  "word": "كلمة",
  "meaning_ar": "Definition in Arabic",
  "meaning_en": "Definition in English",
  "meaning_ur": "Definition in Urdu",
  "root_word": "كلم",
  "history": "Etymology and historical context",
  "examples": "Usage examples",
  "related_words": "Related terms and derivatives"
}
```

## 🔒 Security Notes

- **API keys** are stored in `.env` file (never commit actual keys)
- **Network requests** use HTTPS encryption
- **Local database** is encrypted on supported devices
- **No user data** is collected or transmitted

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Google Gemini** for AI-powered definitions
- **Flutter team** for the amazing framework
- **Dictionary sources** for comprehensive Arabic content
- **Open source community** for various libraries and tools

## 📞 Support

For support, please:
- Open an issue on GitHub
- Contact: [your-email@example.com]
- Check the [FAQ](docs/FAQ.md) for common questions

## 🗺️ Roadmap

- [ ] Audio pronunciation support
- [ ] Offline mode optimization
- [ ] More dictionary sources
- [ ] Word of the day feature
- [ ] Favorites and bookmarks
- [ ] Share functionality
- [ ] iOS app store release

---

**Made with ❤️ for the Arabic language community**
