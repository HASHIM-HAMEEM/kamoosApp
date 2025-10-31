// This file explains how to get and install the Jameel Noori Nastaleeq font in the app.

/*
Steps to install the Jameel Noori Nastaleeq font:

1. First, you need to obtain the Jameel Noori Nastaleeq font file:
   - The font is distributed with Microsoft Office (Urdu language support)
   - You can also find it in some Urdu text processing software
   - Ensure you have proper licensing to use the font

2. Once you have the .ttf file:
   - Rename it to "JameelNooriNastaleeq.ttf"
   - Place it in the assets/fonts/ directory

3. After adding the font file, the app will automatically use it as specified
   in the ThemeData configuration in main.dart

Alternative approach (if you can't get the specific font file):
You can use a similar Arabic Nastaliq font, but make sure to update the
pubspec.yaml file with the correct font family name and file name.

The app will continue to function with system fonts if the specified font
is not found, but the Arabic text will look best with a proper Nastaliq font
like Jameel Noori Nastaleeq.
*/