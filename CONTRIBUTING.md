# Contributing to Home OS

Thank you for your interest in contributing to **Home OS**! 🎉

As a privacy-first, learning-driven operating system, we welcome contributions from developers interested in OS dev, Zig, and low-level programming.

## Getting Started

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally.
3. **Install Dependencies**:
   - **Zig 0.15.2** (Strict version requirement)
   - **QEMU** (For testing and emulation: `qemu-system-i386`)
   - **Python 3** (For running our strict test suite)

## Development Workflow

1. Create a new branch for your feature or bugfix: `git checkout -b feature/my-new-feature`
2. Make your changes in the `src/` directory.
3. Test your changes by compiling: `zig build`
4. Run the automated test suite to verify code quality and logic structural checks:
   ```bash
   python3 test_homeos.py
   ```
   **Note**: Your pull request will not be accepted if the test suite outputs any Failures or Warnings.
5. Format your code before committing: `zig fmt src/`
6. Commit your changes with a descriptive message: `git commit -m "feat: added new network protocol"`
7. Push to your fork and submit a Pull Request!

## Code Guidelines
- **No Telemetry**: Absolutely no data collection or phone-home code will be accepted.
- **Safety**: Ensure operations like array accesses, pointer casting, and integer division are appropriately checked or bounded.
- **Style**: Follow standard Zig conventions as enforced by `zig fmt`.

## How to Get Help
If you encounter an issue, feel free to open a Discussion or an Issue on the GitHub repository.

Happy Hacking!
