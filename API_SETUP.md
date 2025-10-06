# OpenAI API Setup for GlowTrack

## Quick Setup

1. **Get your OpenAI API key:**
   - Go to [OpenAI Platform](https://platform.openai.com/api-keys)
   - Create a new API key
   - Copy the key (starts with `sk-`)

2. **Configure the app:**
   - Open `GlowTrack/Config.swift` in Xcode
   - Replace `YOUR_API_KEY_HERE` with your actual API key:
   ```swift
   static let openAIAPIKey = "sk-your-actual-api-key-here"
   ```

3. **Build and run!**
   - The app will now use ChatGPT to analyze ingredients

## Features

- **AI-Powered Analysis**: Type any dish name and get detailed ingredient breakdown
- **Acne Risk Assessment**: Each ingredient shows Low/Medium/High risk with explanations
- **Smart Suggestions**: Select relevant ingredients for your meal log
- **Fallback System**: If API fails, uses local ingredient suggestions

## Example Usage

1. Open "Log Your Meal"
2. Choose meal type (Breakfast/Lunch/Dinner/Snack)
3. Set time (optional)
4. Type dish name (e.g., "Pizza", "Caesar salad")
5. Tap the ✨ sparkles icon
6. Select ingredients from AI analysis
7. Save your meal!

## Troubleshooting

- **"API key not found"**: Make sure you've replaced the placeholder in Config.swift
- **No ingredients shown**: Check your internet connection and API key
- **App crashes**: Verify your API key is valid and has credits

## Cost

- Uses GPT-3.5-turbo (very affordable)
- Typical cost: ~$0.001-0.002 per analysis
- Free tier: $5 credit for new accounts
