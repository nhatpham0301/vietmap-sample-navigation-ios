<div align="center">
  <img src="https://github.com/flitsmeister/flitsmeister-navigation-ios/blob/master/.github/splash-image-ios.png" alt="Flitsmeister Navigation iOS Splash">
</div>
<br>

# Getting Started

If you are looking to include this inside your project, you have to follow the the following steps:

1. Install Carthage
   - Open terminal
   - [optional] On M1 Mac change terminal to bash: `chsh -s /bin/bash`
   - [Install Homebrew](https://brew.sh/): `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
   - [Install Carthage](https://formulae.brew.sh/formula/carthage): `brew install carthage`

1. Build the frameworks
   - Open terminal
   - Change location to root of XCode project: `cd path/to/Project`
   - Run: `carthage bootstrap --platform iOS --use-xcframeworks`
   - New files will be added
     - Cartfile.resolved = Indicates which frameworks have been fetched/built
     - Carthage folder = Contains all builded frameworks

1. [optional] When app is running on device and you're having problems: Add `arm64` to `PROJECT -> <Project naam> -> Build Settings -> Excluded Architecture Only`
1. Use the sample code as inspiration