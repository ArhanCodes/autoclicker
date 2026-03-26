# autoclicker

An autoclicker for MacOS in Swift using CGEventTap

## Features
- Configurable clicks per second (up to 1000 CPS)
- Left or right click mode
- Toggle with Ctrl+Shift+A or mouse side buttons
- Quit with Ctrl+Shift+Q

## Build & Run
```bash
swiftc autoclicker.swift -o autoclicker -framework Cocoa
./autoclicker
```

### Options
```bash
./autoclicker --cps 50         # Set speed to 50 CPS
./autoclicker --right          # Right click mode

```

