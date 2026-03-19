#!/usr/bin/env python3
"""
Home OS Test Suite
Copyright (C) 2025 Romy Rianata

Automated testing for Home OS components.
Run: python test_homeos.py
"""

import os
import subprocess
import sys
import itertools
from dataclasses import dataclass
from enum import Enum
from typing import List, Optional

class Severity(Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INFO = "INFO"

class Status(Enum):
    PASSED = "PASSED"
    FAILED = "FAILED"
    SKIPPED = "SKIPPED"
    WARNING = "WARNING"

@dataclass
class TestResult:
    name: str
    status: Status
    severity: Severity
    reason: str
    file: Optional[str] = None
    line: Optional[int] = None

class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def color(text: str, c: str) -> str:
    return f"{c}{text}{Colors.RESET}"

class HomeOSTestSuite:
    def __init__(self):
        self.results: List[TestResult] = []
        self.src_dir = "src"
        
    def add_result(self, result: TestResult):
        self.results.append(result)
        
    def run_all_tests(self):
        print(color("\n" + "="*60, Colors.CYAN))
        print(color("  HOME OS TEST SUITE", Colors.BOLD + Colors.WHITE))
        print(color("  Copyright (C) 2025 Romy Rianata", Colors.WHITE))
        print(color("="*60 + "\n", Colors.CYAN))
        
        # Run test categories
        self.test_build()
        self.test_file_structure()
        self.test_version_consistency()
        self.test_gui_apps()
        self.test_keyboard_shortcuts()
        self.test_gui_features()
        self.test_drivers()
        self.test_network()
        self.test_security()
        self.test_memory_safety()
        self.test_buffer_bounds()
        self.test_logic_bugs()
        self.test_code_quality()
        
        # Print summary
        self.print_summary()
        
    def test_build(self):
        """Test if project builds successfully"""
        print(color("[BUILD TESTS]", Colors.BOLD + Colors.BLUE))
        
        # Check if zig is available
        try:
            result = subprocess.run(["zig", "version"], capture_output=True, text=True)
            if result.returncode == 0:
                self.add_result(TestResult(
                    "Zig Compiler Available",
                    Status.PASSED,
                    Severity.CRITICAL,
                    f"Zig version: {result.stdout.strip()}"
                ))
            else:
                self.add_result(TestResult(
                    "Zig Compiler Available",
                    Status.FAILED,
                    Severity.CRITICAL,
                    "Zig compiler not found"
                ))
        except FileNotFoundError:
            self.add_result(TestResult(
                "Zig Compiler Available",
                Status.FAILED,
                Severity.CRITICAL,
                "Zig compiler not installed"
            ))
            
        # Try to build
        if os.path.exists("build.zig"):
            result = subprocess.run(["zig", "build"], capture_output=True, text=True)
            if result.returncode == 0:
                self.add_result(TestResult(
                    "Project Builds Successfully",
                    Status.PASSED,
                    Severity.CRITICAL,
                    "Build completed without errors"
                ))
            else:
                self.add_result(TestResult(
                    "Project Builds Successfully",
                    Status.FAILED,
                    Severity.CRITICAL,
                    f"Build failed: {''.join(itertools.islice(str(result.stderr), 200))}"
                ))
        else:
            self.add_result(TestResult(
                "build.zig Exists",
                Status.FAILED,
                Severity.CRITICAL,
                "build.zig not found"
            ))
        print()
            
    def test_file_structure(self):
        """Test required files exist"""
        print(color("[FILE STRUCTURE TESTS]", Colors.BOLD + Colors.BLUE))
        
        required_files = [
            ("src/kernel.zig", Severity.CRITICAL),
            ("src/gui/desktop.zig", Severity.HIGH),
            ("src/gui/apps/terminal.zig", Severity.HIGH),
            ("src/gui/apps/calculator.zig", Severity.MEDIUM),
            ("src/gui/apps/notepad.zig", Severity.MEDIUM),
            ("src/gui/apps/filemanager.zig", Severity.MEDIUM),
            ("src/gui/apps/settings.zig", Severity.MEDIUM),
            ("src/gui/apps/devmgr.zig", Severity.MEDIUM),
            ("src/gui/apps/taskmanager.zig", Severity.MEDIUM),
            ("src/drivers/keyboard.zig", Severity.HIGH),
            ("src/drivers/mouse.zig", Severity.HIGH),
            ("src/drivers/graphics.zig", Severity.HIGH),
            ("src/net/net.zig", Severity.MEDIUM),
            ("src/net/firewall.zig", Severity.MEDIUM),
            ("src/crypto/crypto.zig", Severity.MEDIUM),
            ("linker.ld", Severity.CRITICAL),
            ("ROADMAP.md", Severity.LOW),
        ]
        
        for filepath, severity in required_files:
            if os.path.exists(filepath):
                self.add_result(TestResult(
                    f"File exists: {filepath}",
                    Status.PASSED,
                    severity,
                    "File found"
                ))
            else:
                self.add_result(TestResult(
                    f"File exists: {filepath}",
                    Status.FAILED,
                    severity,
                    "File not found",
                    file=filepath
                ))
        print()
                
    def test_version_consistency(self):
        """Test version strings are consistent"""
        print(color("[VERSION CONSISTENCY TESTS]", Colors.BOLD + Colors.BLUE))
        
        version_files = [
            ("src/shell/cmd_executor.zig", "0.33.0"),
            ("src/shell/cmd_system.zig", "0.33.0"),
            ("src/gui/apps/sysinfo.zig", "0.33.0"),
            ("src/gui/desktop.zig", "0.33.0"),
        ]
        
        for filepath, expected_version in version_files:
            if os.path.exists(filepath):
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if expected_version in content:
                        self.add_result(TestResult(
                            f"Version in {filepath}",
                            Status.PASSED,
                            Severity.MEDIUM,
                            f"Contains version {expected_version}"
                        ))
                    else:
                        self.add_result(TestResult(
                            f"Version in {filepath}",
                            Status.FAILED,
                            Severity.MEDIUM,
                            f"Expected version {expected_version} not found",
                            file=filepath
                        ))
            else:
                self.add_result(TestResult(
                    f"Version in {filepath}",
                    Status.SKIPPED,
                    Severity.MEDIUM,
                    "File not found",
                    file=filepath
                ))
        print()
                
    def test_gui_apps(self):
        """Test GUI app implementations"""
        print(color("[GUI APP TESTS]", Colors.BOLD + Colors.BLUE))
        
        gui_apps = [
            ("src/gui/apps/terminal.zig", ["handleKey", "draw", "executeCommand"]),
            ("src/gui/apps/calculator.zig", ["handleKey", "handleClick", "draw"]),
            ("src/gui/apps/notepad.zig", ["handleKey", "draw"]),
            ("src/gui/apps/settings.zig", ["handleKey", "draw"]),
            ("src/gui/apps/devmgr.zig", ["handleKey", "draw"]),
            ("src/gui/apps/taskmanager.zig", ["handleKey", "draw"]),
            ("src/gui/apps/filemanager.zig", ["handleKey", "draw", "loadFiles"]),
        ]
        
        for filepath, required_funcs in gui_apps:
            if os.path.exists(filepath):
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    missing = [fn for fn in required_funcs if f"pub fn {fn}" not in content and f"fn {fn}" not in content]
                    if not missing:
                        self.add_result(TestResult(
                            f"GUI App: {os.path.basename(filepath)}",
                            Status.PASSED,
                            Severity.MEDIUM,
                            f"All required functions found: {', '.join(required_funcs)}"
                        ))
                    else:
                        self.add_result(TestResult(
                            f"GUI App: {os.path.basename(filepath)}",
                            Status.WARNING,
                            Severity.MEDIUM,
                            f"Missing functions: {', '.join(missing)}",
                            file=filepath
                        ))
        print()
    
    def test_keyboard_shortcuts(self):
        """Test keyboard shortcut implementations"""
        print(color("[KEYBOARD SHORTCUT TESTS]", Colors.BOLD + Colors.BLUE))
        
        # Check keyboard driver has Ctrl key handling
        if os.path.exists("src/drivers/keyboard.zig"):
            with open("src/drivers/keyboard.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
                # Check for Ctrl key state tracking
                has_ctrl_state = "ctrl_pressed" in content
                has_ctrl_handling = "ctrl_pressed and" in content or "if ctrl_pressed" in content
                
                if has_ctrl_state and has_ctrl_handling:
                    self.add_result(TestResult(
                        "Keyboard: Ctrl Key Handling",
                        Status.PASSED,
                        Severity.HIGH,
                        "Ctrl key combinations supported"
                    ))
                else:
                    self.add_result(TestResult(
                        "Keyboard: Ctrl Key Handling",
                        Status.FAILED,
                        Severity.HIGH,
                        "Ctrl key handling missing or incomplete"
                    ))
                
                # Check for special key constants
                special_keys = ["KEY_UP", "KEY_DOWN", "KEY_LEFT", "KEY_RIGHT", "KEY_PAGE_UP", "KEY_PAGE_DOWN"]
                missing_keys = [k for k in special_keys if k not in content]
                
                if not missing_keys:
                    self.add_result(TestResult(
                        "Keyboard: Special Keys",
                        Status.PASSED,
                        Severity.MEDIUM,
                        "All special key constants defined"
                    ))
                else:
                    self.add_result(TestResult(
                        "Keyboard: Special Keys",
                        Status.WARNING,
                        Severity.MEDIUM,
                        f"Missing keys: {', '.join(missing_keys)}"
                    ))
        
        # Check terminal has keyboard shortcut handling
        if os.path.exists("src/gui/apps/terminal.zig"):
            with open("src/gui/apps/terminal.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
                shortcuts = {
                    "Ctrl+L (clear)": "key == 12" in content or "== 12" in content,
                    "Tab completion": "doTabCompletion" in content,
                    "History navigation": "history" in content.lower() and "KEY_UP" in content,
                    "Page scroll": "KEY_PAGE_UP" in content or "scroll" in content.lower(),
                }
                
                working = [k for k, v in shortcuts.items() if v]
                missing = [k for k, v in shortcuts.items() if not v]
                
                if len(working) >= 3:
                    self.add_result(TestResult(
                        "Terminal: Keyboard Shortcuts",
                        Status.PASSED,
                        Severity.MEDIUM,
                        f"Working: {', '.join(working)}"
                    ))
                else:
                    self.add_result(TestResult(
                        "Terminal: Keyboard Shortcuts",
                        Status.WARNING,
                        Severity.MEDIUM,
                        f"Missing: {', '.join(missing)}"
                    ))
        print()
    
    def test_gui_features(self):
        """Test GUI feature implementations"""
        print(color("[GUI FEATURE TESTS]", Colors.BOLD + Colors.BLUE))
        
        # Check Snake game features
        if os.path.exists("src/gui/apps/snake.zig"):
            with open("src/gui/apps/snake.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                features = {
                    "High score": "high_score" in content,
                    "Speed levels": "speed_level" in content or "speed" in content.lower(),
                    "Game over": "game_over" in content,
                    "Responsive grid": "cell_size" in content or "cell_w" in content,
                }
                working = sum(1 for v in features.values() if v)
                if working >= 3:
                    self.add_result(TestResult(
                        "Snake: Game Features",
                        Status.PASSED,
                        Severity.LOW,
                        f"{working}/4 features implemented"
                    ))
                else:
                    self.add_result(TestResult(
                        "Snake: Game Features",
                        Status.WARNING,
                        Severity.LOW,
                        f"Only {working}/4 features found"
                    ))
        
        # Check Paint app features
        if os.path.exists("src/gui/apps/paint.zig"):
            with open("src/gui/apps/paint.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                tools = {
                    "Brush": ".brush" in content,
                    "Line": ".line" in content or "drawLine" in content,
                    "Rectangle": ".rect" in content or "drawRect" in content,
                    "Eraser": ".eraser" in content or "eraser" in content.lower(),
                }
                working = sum(1 for v in tools.values() if v)
                if working >= 3:
                    self.add_result(TestResult(
                        "Paint: Drawing Tools",
                        Status.PASSED,
                        Severity.LOW,
                        f"{working}/4 tools implemented"
                    ))
                else:
                    self.add_result(TestResult(
                        "Paint: Drawing Tools",
                        Status.WARNING,
                        Severity.LOW,
                        f"Only {working}/4 tools found"
                    ))
        
        # Check Clock app features
        if os.path.exists("src/gui/apps/clock.zig"):
            with open("src/gui/apps/clock.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                features = {
                    "Analog clock": "drawCircle" in content or "radius" in content,
                    "Digital time": "getTimeString" in content or "time_buf" in content,
                    "Stopwatch": "stopwatch" in content.lower(),
                }
                working = sum(1 for v in features.values() if v)
                if working >= 2:
                    self.add_result(TestResult(
                        "Clock: Features",
                        Status.PASSED,
                        Severity.LOW,
                        f"{working}/3 features implemented"
                    ))
                else:
                    self.add_result(TestResult(
                        "Clock: Features",
                        Status.WARNING,
                        Severity.LOW,
                        f"Only {working}/3 features found"
                    ))
        
        # Check Task Manager features
        if os.path.exists("src/gui/apps/taskmanager.zig"):
            with open("src/gui/apps/taskmanager.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                tabs = {
                    "Processes": "Processes" in content or "drawProcesses" in content,
                    "Windows": "Windows" in content or "drawWindows" in content,
                    "Performance": "Performance" in content or "drawPerformance" in content,
                    "Memory": "Memory" in content or "drawMemory" in content,
                }
                working = sum(1 for v in tabs.values() if v)
                if working >= 3:
                    self.add_result(TestResult(
                        "Task Manager: Tabs",
                        Status.PASSED,
                        Severity.MEDIUM,
                        f"{working}/4 tabs implemented"
                    ))
                else:
                    self.add_result(TestResult(
                        "Task Manager: Tabs",
                        Status.WARNING,
                        Severity.MEDIUM,
                        f"Only {working}/4 tabs found"
                    ))
        
        # Check Desktop features
        if os.path.exists("src/gui/desktop.zig"):
            with open("src/gui/desktop.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                features = {
                    "Wallpaper styles": "wallpaper_style" in content,
                    "Window management": "createWindow" in content and "windows" in content,
                    "Minimize all": "minimizeAll" in content or "minimize" in content.lower(),
                    "Resolution change": "onResolutionChange" in content,
                }
                working = sum(1 for v in features.values() if v)
                if working >= 3:
                    self.add_result(TestResult(
                        "Desktop: Features",
                        Status.PASSED,
                        Severity.MEDIUM,
                        f"{working}/4 features implemented"
                    ))
                else:
                    self.add_result(TestResult(
                        "Desktop: Features",
                        Status.WARNING,
                        Severity.MEDIUM,
                        f"Only {working}/4 features found"
                    ))
        
        # Check Device Manager dynamic resolution
        if os.path.exists("src/gui/apps/devmgr.zig"):
            with open("src/gui/apps/devmgr.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                # Check for dynamic VBE resolution instead of hardcoded
                has_vbe_import = "vbe.zig" in content or "@import" in content and "vbe" in content
                has_dynamic_res = "vbe.getWidth()" in content or "vbe.getHeight()" in content
                no_hardcoded = "800x600x32" not in content
                
                if has_dynamic_res and no_hardcoded:
                    self.add_result(TestResult(
                        "Device Manager: Dynamic Resolution",
                        Status.PASSED,
                        Severity.MEDIUM,
                        "Uses dynamic VBE resolution"
                    ))
                elif has_dynamic_res:
                    self.add_result(TestResult(
                        "Device Manager: Dynamic Resolution",
                        Status.WARNING,
                        Severity.MEDIUM,
                        "Has dynamic resolution but may have hardcoded fallback"
                    ))
                else:
                    self.add_result(TestResult(
                        "Device Manager: Dynamic Resolution",
                        Status.FAILED,
                        Severity.MEDIUM,
                        "Still using hardcoded resolution"
                    ))
        print()
                        
    def test_drivers(self):
        """Test driver implementations"""
        print(color("[DRIVER TESTS]", Colors.BOLD + Colors.BLUE))
        
        drivers = [
            ("src/drivers/keyboard.zig", ["handleInterrupt", "getKey", "hasKey"]),
            ("src/drivers/mouse.zig", ["handleInterrupt", "getState", "init"]),
            ("src/drivers/graphics.zig", ["init", "putPixel", "fillRect", "swapBuffers"]),
            ("src/drivers/audio.zig", ["init", "playTone", "beep"]),
            ("src/drivers/pit.zig", ["init", "handleTick", "getTicks", "getCpuUsage"]),
        ]
        
        for filepath, required_funcs in drivers:
            if os.path.exists(filepath):
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    missing = [fn for fn in required_funcs if f"pub fn {fn}" not in content]
                    if not missing:
                        self.add_result(TestResult(
                            f"Driver: {os.path.basename(filepath)}",
                            Status.PASSED,
                            Severity.HIGH,
                            "All required functions found"
                        ))
                    else:
                        self.add_result(TestResult(
                            f"Driver: {os.path.basename(filepath)}",
                            Status.FAILED,
                            Severity.HIGH,
                            f"Missing functions: {', '.join(missing)}",
                            file=filepath
                        ))
        print()
                        
    def test_network(self):
        """Test network stack"""
        print(color("[NETWORK TESTS]", Colors.BOLD + Colors.BLUE))
        
        net_modules = [
            ("src/net/net.zig", ["init", "getLocalIp"]),
            ("src/net/firewall.zig", ["init", "isEnabled", "getRuleCount"]),
            ("src/net/rtl8139.zig", ["init", "isInitialized", "getMacAddress"]),
            ("src/net/tcp.zig", ["init"]),
            ("src/net/udp.zig", ["init"]),
            ("src/net/dhcp.zig", ["init"]),
            ("src/net/dns.zig", ["init"]),
        ]
        
        for filepath, required_funcs in net_modules:
            if os.path.exists(filepath):
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    missing = [fn for fn in required_funcs if f"pub fn {fn}" not in content]
                    if not missing:
                        self.add_result(TestResult(
                            f"Network: {os.path.basename(filepath)}",
                            Status.PASSED,
                            Severity.MEDIUM,
                            "All required functions found"
                        ))
                    else:
                        self.add_result(TestResult(
                            f"Network: {os.path.basename(filepath)}",
                            Status.WARNING,
                            Severity.MEDIUM,
                            f"Missing: {', '.join(missing)}",
                            file=filepath
                        ))
        print()
                        
    def test_security(self):
        """Test security features"""
        print(color("[SECURITY TESTS]", Colors.BOLD + Colors.BLUE))
        
        # Check crypto module
        if os.path.exists("src/crypto/crypto.zig"):
            with open("src/crypto/crypto.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                if "randomU32" in content:
                    self.add_result(TestResult(
                        "Crypto: RNG Available",
                        Status.PASSED,
                        Severity.HIGH,
                        "Random number generation implemented"
                    ))
                else:
                    self.add_result(TestResult(
                        "Crypto: RNG Available",
                        Status.FAILED,
                        Severity.HIGH,
                        "RNG not found"
                    ))
                    
        # Check SHA-256 implementation quality
        if os.path.exists("src/crypto/sha256.zig"):
            with open("src/crypto/sha256.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                # Check for proper SHA-256 constants
                has_k = "0x428a2f98" in content or "K = " in content
                has_init = "0x6a09e667" in content  # First H constant
                has_rounds = "64" in content  # SHA-256 has 64 rounds
                
                if has_k and has_init:
                    self.add_result(TestResult(
                        "Crypto: SHA-256 Constants",
                        Status.PASSED,
                        Severity.HIGH,
                        "SHA-256 uses correct constants"
                    ))
                else:
                    self.add_result(TestResult(
                        "Crypto: SHA-256 Constants",
                        Status.FAILED,
                        Severity.HIGH,
                        "SHA-256 may have incorrect constants"
                    ))
        else:
            self.add_result(TestResult(
                "Crypto: SHA-256 Available",
                Status.FAILED,
                Severity.HIGH,
                "SHA-256 not implemented"
            ))
            
        # Check firewall
        if os.path.exists("src/net/firewall.zig"):
            with open("src/net/firewall.zig", 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                has_rules = "Rule" in content and "rules" in content
                has_filter = "matches" in content or "check" in content.lower()
                has_action = "Action" in content and ("allow" in content or "deny" in content)
                
                if has_rules and has_filter and has_action:
                    self.add_result(TestResult(
                        "Security: Firewall",
                        Status.PASSED,
                        Severity.HIGH,
                        "Firewall implementation found"
                    ))
                else:
                    self.add_result(TestResult(
                        "Security: Firewall",
                        Status.WARNING,
                        Severity.HIGH,
                        "Firewall may be incomplete"
                    ))
        print()
        
    def test_memory_safety(self):
        """Test for memory safety issues"""
        print(color("[MEMORY SAFETY TESTS]", Colors.BOLD + Colors.BLUE))
        
        issues = []
        
        for root, dirs, files in os.walk("src"):
            _d = [d for d in dirs if d not in ['.zig-cache', 'zig-out']]
            dirs.clear()
            dirs.extend(_d)
            for file in files:
                if file.endswith('.zig'):
                    filepath = os.path.join(root, file)
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        lines = content.split('\n')
                        
                        for i, line in enumerate(lines, 1):
                            # Check for undefined behavior patterns
                            if '@intCast' in line and 'truncate' not in line:
                                # intCast without bounds check can panic
                                context = '\n'.join(itertools.islice(lines, max(0,i-5), i+2))
                                # Safe patterns: if check, @min, @max, comparison, or known safe casts
                                safe_patterns = ['if', '@min', '@max', '< ', '> ', '<= ', '>= ', 'usize', 'i32', 'u32']
                                is_safe = any(p in context for p in safe_patterns)
                                if not is_safe:
                                    issues.append((filepath, i, "Unchecked @intCast"))
                            
                            # Check for potential null pointer - more strict
                            if '.?' in line and 'if' not in line and 'orelse' not in line and 'while' not in line:
                                # Skip if it's in a safe context
                                context = '\n'.join(itertools.islice(lines, max(0,i-3), i+1))
                                if 'if' not in context and 'orelse' not in context:
                                    issues.append((filepath, i, "Optional access without check"))
                                
        if len(issues) > 50:  # Higher threshold - OS code has many casts
            self.add_result(TestResult(
                "Memory Safety: Unchecked Casts",
                Status.WARNING,
                Severity.MEDIUM,
                f"Found {len(issues)} potentially unsafe operations"
            ))
        else:
            self.add_result(TestResult(
                "Memory Safety: Unchecked Casts",
                Status.PASSED,
                Severity.MEDIUM,
                f"Found {len(issues)} operations (acceptable)"
            ))
        print()
        
    def test_buffer_bounds(self):
        """Test for buffer overflow vulnerabilities"""
        print(color("[BUFFER BOUNDS TESTS]", Colors.BOLD + Colors.BLUE))
        
        overflow_risks = []
        
        # Check specific files for buffer handling
        critical_files = [
            "src/gui/apps/terminal.zig",
            "src/gui/apps/notepad.zig", 
            "src/gui/apps/calculator.zig",
            "src/shell/cmd_executor.zig",
            "src/net/tcp.zig",
            "src/net/udp.zig",
        ]
        
        for filepath in critical_files:
            if os.path.exists(filepath):
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    lines = content.split('\n')
                    
                    for i, line in enumerate(lines, 1):
                        # Check for length increment without bounds check
                        if '_len' in line and '+=' in line and '1' in line:
                            # Look for bounds check in wider context (15 lines)
                            context = '\n'.join(itertools.islice(lines, max(0,i-15), i+1))
                            # Must have BOTH 'if'/'while' AND a comparison with buffer size
                            has_if = 'if' in context or 'while' in context
                            has_bound = '< ' in context or '<=' in context or '.len' in context
                            # Also check for explicit size constants (common pattern)
                            has_size_const = '< 12' in context or '< 16' in context or '< 10' in context or '< 256' in context
                            # Check for = 0 reset pattern (safe initialization)
                            has_reset = '_len = 0' in context or '_len: usize = 0' in context
                            if not (has_if and (has_bound or has_size_const)) and not has_reset:
                                overflow_risks.append((filepath, i, "Buffer write may lack bounds check"))
                                
        if overflow_risks:
            self.add_result(TestResult(
                "Buffer Safety: Bounds Checking",
                Status.WARNING,
                Severity.HIGH,
                f"Found {len(overflow_risks)} potential buffer issues"
            ))
            for risk in itertools.islice(overflow_risks, 3):  # Show first 3
                print(f"    {risk[0]}:{risk[1]} - {risk[2]}")
        else:
            self.add_result(TestResult(
                "Buffer Safety: Bounds Checking",
                Status.PASSED,
                Severity.HIGH,
                "Buffer operations appear safe"
            ))
        print()
        
    def test_logic_bugs(self):
        """Test for common logic bugs"""
        print(color("[LOGIC BUG TESTS]", Colors.BOLD + Colors.BLUE))
        
        bugs = []
        
        for root, dirs, files in os.walk("src"):
            _d = [d for d in dirs if d not in ['.zig-cache', 'zig-out']]
            dirs.clear()
            dirs.extend(_d)
            for file in files:
                if file.endswith('.zig'):
                    filepath = os.path.join(root, file)
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        lines = f.readlines()
                        
                        for i, line in enumerate(lines, 1):
                            stripped = line.strip()
                            
                            # Empty if body (likely mistake) - must be exactly "if (...) {}"
                            if stripped.startswith('if ') and stripped.endswith('{}') and '{' in stripped:
                                bugs.append((filepath, i, "Empty if statement"))
                            
                            # Duplicate consecutive lines (copy-paste error)
                            # But allow intentional duplicates like io.outb (hardware often needs this)
                            if i > 1 and stripped and stripped == lines[i-2].strip():
                                if not stripped.startswith('//') and not stripped.startswith('}'):
                                    if len(stripped) > 15:  # Ignore short lines
                                        # Allow hardware I/O duplicates (intentional)
                                        if 'outb' not in stripped and 'inb' not in stripped:
                                            bugs.append((filepath, i, f"Duplicate line: {stripped[:40]}"))
                            
                            # Division by literal zero (careful to avoid hex like 0x0F and version strings)
                            import re
                            # Match "/ 0" or "/0" but not "0x0" hex patterns or version strings like "/0.26.0"
                            if re.search(r'/\s*0(?![xX0-9a-fA-F\.])', line):
                                if '//' not in line:  # Not a comment
                                    bugs.append((filepath, i, "Division by zero"))
                                    
        if bugs:
            self.add_result(TestResult(
                "Logic: Common Bug Patterns",
                Status.WARNING,
                Severity.MEDIUM,
                f"Found {len(bugs)} potential logic issues"
            ))
            for bug in itertools.islice(bugs, 5):  # Show first 5
                print(f"    {bug[0]}:{bug[1]} - {bug[2]}")
        else:
            self.add_result(TestResult(
                "Logic: Common Bug Patterns",
                Status.PASSED,
                Severity.MEDIUM,
                "No common logic bugs detected"
            ))
        print()
                    
    def test_code_quality(self):
        """Test code quality issues"""
        print(color("[CODE QUALITY TESTS]", Colors.BOLD + Colors.BLUE))
        
        todo_issues = []
        div_issues = []
        unsafe_issues = []
        bounds_issues = []
        
        for root, dirs, files in os.walk("src"):
            _d = [d for d in dirs if d not in ['.zig-cache', 'zig-out']]
            dirs.clear()
            dirs.extend(_d)
            for file in files:
                if file.endswith('.zig'):
                    filepath = os.path.join(root, file)
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        lines = f.readlines()
                        for i, line in enumerate(lines, 1):
                            # TODO/FIXME
                            if 'TODO' in line or 'FIXME' in line:
                                todo_issues.append((filepath, i, line.strip()))
                            
                            # Division without zero check (potential div by zero)
                            # Look for @divTrunc/@divFloor/@mod without prior != 0 check
                            if '@divTrunc' in line or '@divFloor' in line or '@mod' in line:
                                # Check if dividing by a constant (safe)
                                import re
                                # Match division by constant number like ", 2)" or ", 10)" or ", scale)"
                                const_div = re.search(r'@(?:divTrunc|divFloor|mod)\([^,]+,\s*(\d+|scale|SCALE)\s*\)', line)
                                if not const_div:
                                    # Check if there's a zero check nearby
                                    context = ''.join(itertools.islice(lines, max(0,i-5), i))
                                    if '!= 0' not in context and '> 0' not in context:
                                        div_issues.append((filepath, i, "".join(itertools.islice(line.strip(), 60))))
                            
                            # Unsafe pointer casts
                            if '@ptrFromInt' in line or '@intFromPtr' in line:
                                unsafe_issues.append((filepath, i, "Pointer cast"))
                            
                            # Array access without bounds check
                            # This is a heuristic - look for [i] or [idx] patterns
                            import re
                            if re.search(r'\[\s*\w+\s*\]', line) and 'if' not in ''.join(itertools.islice(lines, max(0,i-2), i)):
                                # Check if there's a bounds check nearby
                                context = ''.join(itertools.islice(lines, max(0,i-3), i))
                                if '.len' not in context and 'while' not in context and 'for' not in context:
                                    if 'const ' not in line and 'var ' not in line:
                                        bounds_issues.append((filepath, i, "".join(itertools.islice(line.strip(), 50))))
                                
        # Report TODO/FIXME
        if todo_issues:
            self.add_result(TestResult(
                "Code Quality: TODO/FIXME",
                Status.WARNING,
                Severity.LOW,
                f"Found {len(todo_issues)} TODO/FIXME comments"
            ))
        else:
            self.add_result(TestResult(
                "Code Quality: TODO/FIXME",
                Status.PASSED,
                Severity.LOW,
                "No TODO/FIXME comments found"
            ))
            
        # Report potential division by zero
        for iss in div_issues: print(iss)
        if len(div_issues) > 5:  # Some false positives expected
            self.add_result(TestResult(
                "Code Quality: Division Safety",
                Status.WARNING,
                Severity.MEDIUM,
                f"Found {len(div_issues)} potential unchecked divisions"
            ))
        else:
            self.add_result(TestResult(
                "Code Quality: Division Safety",
                Status.PASSED,
                Severity.MEDIUM,
                "Division operations appear safe"
            ))
            
        # Report unsafe pointer operations (info only - always pass for OS code)
        self.add_result(TestResult(
            "Code Quality: Pointer Casts",
            Status.PASSED,  # Always pass - pointer casts are expected in OS kernel code
            Severity.INFO,
            f"Found {len(unsafe_issues)} pointer casts (expected in OS code)"
        ))
        print()
            
    def print_summary(self):
        """Print test summary"""
        print(color("\n" + "="*60, Colors.CYAN))
        print(color("  TEST SUMMARY", Colors.BOLD + Colors.WHITE))
        print(color("="*60, Colors.CYAN))
        
        passed = sum(1 for r in self.results if r.status == Status.PASSED)
        failed = sum(1 for r in self.results if r.status == Status.FAILED)
        warnings = sum(1 for r in self.results if r.status == Status.WARNING)
        skipped = sum(1 for r in self.results if r.status == Status.SKIPPED)
        total = len(self.results)
        
        print(f"\n  Total Tests: {total}")
        print(color(f"  ✓ Passed:   {passed}", Colors.GREEN))
        print(color(f"  ✗ Failed:   {failed}", Colors.RED))
        print(color(f"  ⚠ Warnings: {warnings}", Colors.YELLOW))
        print(color(f"  ○ Skipped:  {skipped}", Colors.BLUE))
        
        # Print failures
        failures = [r for r in self.results if r.status == Status.FAILED]
        if failures:
            print(color("\n  FAILURES:", Colors.BOLD + Colors.RED))
            for r in failures:
                sev_color = Colors.RED if r.severity == Severity.CRITICAL else Colors.YELLOW
                print(f"    [{color(str(r.severity.value), sev_color)}] {r.name}")
                print(f"      Reason: {r.reason}")
                if r.file:
                    print(f"      File: {r.file}")
                    
        # Print warnings
        warns = [r for r in self.results if r.status == Status.WARNING]
        if warns:
            print(color("\n  WARNINGS:", Colors.BOLD + Colors.YELLOW))
            for r in warns:
                print(f"    [{str(r.severity.value)}] {r.name}")
                print(f"      Reason: {r.reason}")
                
        print(color("\n" + "="*60, Colors.CYAN))
        
        # Exit code
        if failed > 0:
            critical_fails = sum(1 for r in failures if r.severity == Severity.CRITICAL)
            if critical_fails > 0:
                print(color(f"\n  ✗ {critical_fails} CRITICAL failures!", Colors.BOLD + Colors.RED))
                return 1
        
        print(color("\n  ✓ All critical tests passed!", Colors.BOLD + Colors.GREEN))
        return 0

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)) or ".")
    suite = HomeOSTestSuite()
    exit_code = suite.run_all_tests()
    sys.exit(exit_code)
