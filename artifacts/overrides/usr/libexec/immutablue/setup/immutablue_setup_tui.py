#!/usr/bin/python3
# immutablue_setup_tui.py
#
# This script provides a text-based user interface (TUI) for the Immutablue
# first-boot setup experience. It guides users through initial system configuration
# when running on systems without a graphical environment (nucleus builds).
#
# The TUI application follows a step-by-step wizard approach for:
# - System introduction
# - Hardware detection and optimization
# - User configuration
# - Network setup
# - Development environment setup
# - Application installation options
#
# Configuration options are drawn from and saved to the Immutablue settings.yaml hierarchy.

import os
import sys
import subprocess
import json
import yaml
import curses
import textwrap
import time
from time import sleep
from pathlib import Path

# Paths for configuration files
DEFAULT_CONFIG_FILE = '/usr/immutablue/setup/first_boot_config.yaml'
SYSTEM_CONFIG_FILE = '/etc/immutablue/setup/first_boot_config.yaml'
USER_CONFIG_FILE = os.path.expanduser('~/.config/immutablue/first_boot_config.yaml')

# Flag file to track completion
COMPLETED_FLAG = '/etc/immutablue/setup/did_first_boot_setup'

class ImmutablueTUI:
    """Text-based user interface for Immutablue setup."""
    
    def __init__(self, config_file=None):
        """Initialize the TUI application.
        
        Args:
            config_file: Optional path to a custom config file that overrides the default hierarchy
        """
        self.screen = None
        self.max_y = 0
        self.max_x = 0
        self.current_step = 0
        self.custom_config_file = config_file
        self.config = self.load_config()
        self.user_selections = {}
        
    def load_config(self):
        """Load configuration from YAML files with hierarchy.
        
        If a custom config file was specified, it takes precedence over all other configurations.
        Otherwise, follows the standard hierarchy:
        1. User configuration
        2. System configuration
        3. Default configuration
        """
        config = {}
        
        # If a custom config file was specified, load only that
        if self.custom_config_file and os.path.exists(self.custom_config_file):
            print(f"Using custom config file: {self.custom_config_file}")
            with open(self.custom_config_file, 'r') as f:
                return yaml.safe_load(f) or {}
        
        # Otherwise follow the standard hierarchy
        # Load default configuration
        if os.path.exists(DEFAULT_CONFIG_FILE):
            with open(DEFAULT_CONFIG_FILE, 'r') as f:
                config.update(yaml.safe_load(f) or {})
                
        # Load system configuration (overrides defaults)
        if os.path.exists(SYSTEM_CONFIG_FILE):
            with open(SYSTEM_CONFIG_FILE, 'r') as f:
                config.update(yaml.safe_load(f) or {})
                
        # Load user configuration (overrides system and defaults)
        if os.path.exists(USER_CONFIG_FILE):
            with open(USER_CONFIG_FILE, 'r') as f:
                config.update(yaml.safe_load(f) or {})
        
        # If no configuration exists, use built-in defaults
        if not config:
            config = {
                'welcome': {
                    'title': 'Welcome to Immutablue',
                    'description': 'This setup will guide you through configuring your new Immutablue system.',
                },
                'steps': [
                    {
                        'id': 'intro',
                        'title': 'Introduction to Immutablue',
                        'description': 'Immutablue is a customized Fedora derivative with an immutable base system. This provides security, reliability, and easy rollback while still allowing customization via containers and user applications.',
                        'type': 'info'
                    },
                    {
                        'id': 'hardware',
                        'title': 'Hardware Detection',
                        'description': 'We\'ll now scan your hardware and apply optimizations.',
                        'type': 'action',
                        'action': 'hardware_detection'
                    },
                    {
                        'id': 'network',
                        'title': 'Network Configuration',
                        'description': 'Configure network settings for your system.',
                        'type': 'action',
                        'action': 'network_setup'
                    },
                    {
                        'id': 'dev_env',
                        'title': 'Development Environment',
                        'description': 'Select development tools to install in your Immutablue system.',
                        'type': 'options',
                        'option_type': 'checkbox',
                        'options': [
                            {'id': 'devbox_base', 'label': 'Basic Development Environment', 'description': 'Includes git, compilers, and standard dev tools', 'default': True},
                            {'id': 'devbox_python', 'label': 'Python Development', 'description': 'Python development environment', 'default': False},
                            {'id': 'devbox_nodejs', 'label': 'Node.js Development', 'description': 'Node.js development environment', 'default': False},
                            {'id': 'devbox_rust', 'label': 'Rust Development', 'description': 'Rust development environment', 'default': False},
                            {'id': 'devbox_go', 'label': 'Go Development', 'description': 'Go development environment', 'default': False}
                        ]
                    },
                    {
                        'id': 'applications',
                        'title': 'Application Installation',
                        'description': 'Select applications to install on your system.',
                        'type': 'options',
                        'option_type': 'checkbox',
                        'options': [
                            {'id': 'app_firefox', 'label': 'Firefox Web Browser', 'description': 'Firefox web browser (Flatpak)', 'default': True},
                            {'id': 'app_vscode', 'label': 'VS Code', 'description': 'Visual Studio Code (Flatpak)', 'default': False},
                            {'id': 'app_libreoffice', 'label': 'LibreOffice', 'description': 'Full office suite (Flatpak)', 'default': False}
                        ]
                    },
                    {
                        'id': 'finish',
                        'title': 'Setup Complete',
                        'description': 'Your Immutablue system has been configured. The system will now reboot to apply all settings.',
                        'type': 'info'
                    }
                ]
            }
        
        return config
    
    def save_selections(self, dry_run=False):
        """Save user selections to the settings file.
        
        Args:
            dry_run: If True, print actions instead of executing them
        """
        user_settings_dir = os.path.expanduser('~/.config/immutablue')
        user_settings_file = os.path.join(user_settings_dir, 'settings.yaml')
        
        # Prepare the settings data
        settings = {}
        
        if not dry_run:
            # Ensure directory exists
            os.makedirs(user_settings_dir, exist_ok=True)
            
            # Load existing settings if present
            if os.path.exists(user_settings_file):
                with open(user_settings_file, 'r') as f:
                    settings = yaml.safe_load(f) or {}
        
        # Ensure immutablue section exists
        if 'immutablue' not in settings:
            settings['immutablue'] = {}
        
        # Ensure setup section exists
        if 'setup' not in settings['immutablue']:
            settings['immutablue']['setup'] = {}
        
        # Add our selections
        settings['immutablue']['setup']['selections'] = self.user_selections
        
        # Add install flags based on selections
        if 'dev_env' in self.user_selections:
            for option in self.user_selections['dev_env']:
                if option.startswith('devbox_') and self.user_selections['dev_env'][option]:
                    settings['immutablue']['setup']['install_distrobox'] = True
        
        if 'applications' in self.user_selections:
            for option in self.user_selections['applications']:
                if option.startswith('app_') and self.user_selections['applications'][option]:
                    settings['immutablue']['setup']['install_flatpaks'] = True
        
        if dry_run:
            # In dry-run mode, just print what would be saved
            print(f"[DRY RUN] Would save settings to: {user_settings_file}")
            print("[DRY RUN] Settings content:")
            yaml_content = yaml.dump(settings, default_flow_style=False)
            for line in yaml_content.splitlines():
                print(f"  {line}")
        else:
            # Write settings back
            with open(user_settings_file, 'w') as f:
                yaml.dump(settings, f, default_flow_style=False)
    
    def run(self):
        """Run the TUI application in curses."""
        return curses.wrapper(self._run_with_curses)
    
    def _run_with_curses(self, screen):
        """Main application loop with curses screen."""
        self.screen = screen
        curses.curs_set(0)  # Hide cursor
        self.screen.clear()
        
        # Get screen dimensions
        self.max_y, self.max_x = self.screen.getmaxyx()
        
        # Show welcome screen
        self._show_welcome()
        
        # Main loop through setup steps
        while self.current_step < len(self.config['steps']):
            step = self.config['steps'][self.current_step]
            
            if step['type'] == 'info':
                self._show_info_step(step)
            elif step['type'] == 'options':
                self._show_options_step(step)
            elif step['type'] == 'action':
                self._show_action_step(step)
            
            # Last step
            if self.current_step == len(self.config['steps']) - 1:
                # Save configurations
                self.save_selections()
                
                # Mark setup as complete
                self._mark_setup_complete()
                
                # Show completion message
                self._show_completion()
                break
            
            self.current_step += 1
    
    def _show_welcome(self):
        """Display the welcome screen."""
        self.screen.clear()
        welcome = self.config.get('welcome', {})
        title = welcome.get('title', 'Welcome to Immutablue')
        description = welcome.get('description', 'This setup will guide you through initial configuration.')
        
        # Draw title
        title_y = int(self.max_y * 0.3)
        title_x = (self.max_x - len(title)) // 2
        self.screen.addstr(title_y, title_x, title, curses.A_BOLD)
        
        # Draw description
        wrapped_desc = textwrap.wrap(description, self.max_x - 10)
        for i, line in enumerate(wrapped_desc):
            desc_y = title_y + 2 + i
            desc_x = (self.max_x - len(line)) // 2
            self.screen.addstr(desc_y, desc_x, line)
        
        # Draw prompt
        prompt = "Press Enter to continue..."
        prompt_y = self.max_y - 3
        prompt_x = (self.max_x - len(prompt)) // 2
        self.screen.addstr(prompt_y, prompt_x, prompt)
        
        self.screen.refresh()
        
        # Wait for Enter key
        while True:
            key = self.screen.getch()
            if key in (curses.KEY_ENTER, 10, 13):
                break
    
    def _show_info_step(self, step):
        """Display an informational step."""
        self.screen.clear()
        
        # Draw title
        title_y = 2
        title_x = (self.max_x - len(step['title'])) // 2
        self.screen.addstr(title_y, title_x, step['title'], curses.A_BOLD)
        
        # Draw description
        wrapped_desc = textwrap.wrap(step['description'], self.max_x - 10)
        for i, line in enumerate(wrapped_desc):
            desc_y = title_y + 2 + i
            desc_x = 5
            self.screen.addstr(desc_y, desc_x, line)
        
        # Draw prompt
        prompt = "Press Enter to continue..."
        prompt_y = self.max_y - 3
        prompt_x = (self.max_x - len(prompt)) // 2
        self.screen.addstr(prompt_y, prompt_x, prompt)
        
        self.screen.refresh()
        
        # Wait for Enter key
        while True:
            key = self.screen.getch()
            if key in (curses.KEY_ENTER, 10, 13):
                break
    
    def _show_options_step(self, step):
        """Display a step with selectable options."""
        option_type = step.get('option_type', 'checkbox')
        options = step.get('options', [])
        step_id = step.get('id', f'step_{self.current_step}')
        
        # Initialize selected options if not already set
        if step_id not in self.user_selections:
            self.user_selections[step_id] = {}
            for option in options:
                self.user_selections[step_id][option['id']] = option.get('default', False)
        
        selected_idx = 0
        
        while True:
            self.screen.clear()
            
            # Draw title
            title_y = 2
            title_x = (self.max_x - len(step['title'])) // 2
            self.screen.addstr(title_y, title_x, step['title'], curses.A_BOLD)
            
            # Draw description
            wrapped_desc = textwrap.wrap(step['description'], self.max_x - 10)
            for i, line in enumerate(wrapped_desc):
                desc_y = title_y + 2 + i
                desc_x = 5
                self.screen.addstr(desc_y, desc_x, line)
            
            # Draw options
            options_start_y = desc_y + 2
            for i, option in enumerate(options):
                is_selected = self.user_selections[step_id][option['id']]
                
                # Highlight the current selection
                if i == selected_idx:
                    attr = curses.A_REVERSE
                else:
                    attr = curses.A_NORMAL
                
                # Draw the checkbox
                if option_type == 'checkbox':
                    checkbox = '[X]' if is_selected else '[ ]'
                    self.screen.addstr(options_start_y + i*2, 5, f"{checkbox} {option['label']}", attr)
                    
                    # Draw description if it exists
                    if 'description' in option:
                        desc = f"   {option['description']}"
                        self.screen.addstr(options_start_y + i*2 + 1, 5, desc[:self.max_x-10])
            
            # Draw instructions
            instructions = "↑/↓: Navigate, Space: Toggle, Enter: Continue"
            instructions_y = self.max_y - 3
            instructions_x = (self.max_x - len(instructions)) // 2
            self.screen.addstr(instructions_y, instructions_x, instructions)
            
            self.screen.refresh()
            
            # Handle key presses
            key = self.screen.getch()
            
            if key == curses.KEY_UP and selected_idx > 0:
                selected_idx -= 1
            elif key == curses.KEY_DOWN and selected_idx < len(options) - 1:
                selected_idx += 1
            elif key == ord(' '):  # Space bar
                # Toggle selection
                option_id = options[selected_idx]['id']
                self.user_selections[step_id][option_id] = not self.user_selections[step_id][option_id]
            elif key in (curses.KEY_ENTER, 10, 13):  # Enter key
                break
    
    def _show_action_step(self, step):
        """Execute an action step and show progress."""
        self.screen.clear()
        
        # Draw title
        title_y = 2
        title_x = (self.max_x - len(step['title'])) // 2
        self.screen.addstr(title_y, title_x, step['title'], curses.A_BOLD)
        
        # Draw description
        wrapped_desc = textwrap.wrap(step['description'], self.max_x - 10)
        for i, line in enumerate(wrapped_desc):
            desc_y = title_y + 2 + i
            desc_x = 5
            self.screen.addstr(desc_y, desc_x, line)
        
        # Draw working message
        msg = "Working, please wait..."
        msg_y = desc_y + 3
        msg_x = 5
        self.screen.addstr(msg_y, msg_x, msg)
        
        # Execute the action based on action type
        action_type = step.get('action', '')
        result_y = msg_y + 2
        
        self.screen.refresh()
        
        # Execute appropriate action
        if action_type == 'hardware_detection':
            self._do_hardware_detection(result_y)
        elif action_type == 'network_setup':
            self._do_network_setup(result_y)
        else:
            # Generic action
            self.screen.addstr(result_y, 5, "Action completed.")
            self.screen.refresh()
            sleep(2)
        
        # Draw completion
        self.screen.addstr(self.max_y - 3, 5, "Press Enter to continue...")
        self.screen.refresh()
        
        # Wait for Enter key
        while True:
            key = self.screen.getch()
            if key in (curses.KEY_ENTER, 10, 13):
                break
    
    def _do_hardware_detection(self, start_y):
        """Perform hardware detection and show results."""
        self.screen.addstr(start_y, 5, "Detecting CPU...")
        self.screen.refresh()
        
        try:
            cpu_info = subprocess.check_output("lscpu | grep 'Model name'", 
                                              shell=True, text=True).strip()
            self.screen.addstr(start_y + 1, 5, cpu_info)
        except:
            self.screen.addstr(start_y + 1, 5, "Could not detect CPU.")
        
        self.screen.refresh()
        sleep(1)
        
        # Detect memory
        self.screen.addstr(start_y + 3, 5, "Detecting Memory...")
        self.screen.refresh()
        
        try:
            mem_info = subprocess.check_output("free -h | grep Mem:", 
                                              shell=True, text=True).strip()
            self.screen.addstr(start_y + 4, 5, mem_info)
        except:
            self.screen.addstr(start_y + 4, 5, "Could not detect memory.")
        
        self.screen.refresh()
        sleep(1)
        
        # Detect GPU
        self.screen.addstr(start_y + 6, 5, "Detecting GPU...")
        self.screen.refresh()
        
        try:
            gpu_info = subprocess.check_output("lspci | grep -i vga", 
                                              shell=True, text=True).strip()
            self.screen.addstr(start_y + 7, 5, gpu_info[:self.max_x-10])
        except:
            self.screen.addstr(start_y + 7, 5, "Could not detect GPU.")
        
        self.screen.refresh()
        sleep(1)
        
        # Store hardware info in selections
        self.user_selections['hardware'] = {
            'detected': True,
            'timestamp': subprocess.check_output("date", shell=True, text=True).strip()
        }
    
    def _do_network_setup(self, start_y):
        """Check network connectivity and show status."""
        self.screen.addstr(start_y, 5, "Checking network connectivity...")
        self.screen.refresh()
        
        # Check internet connectivity
        try:
            result = subprocess.run(["ping", "-c", "1", "-W", "2", "9.9.9.9"], 
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            if result.returncode == 0:
                self.screen.addstr(start_y + 1, 5, "Internet connection: ✓")
                self.user_selections['network'] = {'internet': True}
            else:
                self.screen.addstr(start_y + 1, 5, "Internet connection: ✗")
                self.user_selections['network'] = {'internet': False}
        except:
            self.screen.addstr(start_y + 1, 5, "Could not check internet connectivity.")
            self.user_selections['network'] = {'internet': False}
        
        self.screen.refresh()
        sleep(1)
        
        # Get network interfaces
        self.screen.addstr(start_y + 3, 5, "Detecting network interfaces...")
        self.screen.refresh()
        
        try:
            interfaces = subprocess.check_output("ip -o link show | awk -F': ' '{print $2}'", 
                                               shell=True, text=True).strip().split('\n')
            
            for i, interface in enumerate(interfaces[:3]):  # Show up to 3 interfaces
                self.screen.addstr(start_y + 4 + i, 5, f"Interface: {interface}")
                
            self.user_selections.setdefault('network', {})['interfaces'] = interfaces
        except:
            self.screen.addstr(start_y + 4, 5, "Could not detect network interfaces.")
        
        self.screen.refresh()
        sleep(1)
    
    def _show_completion(self):
        """Display the completion screen."""
        self.screen.clear()
        
        # Draw completion message
        title = "Setup Complete!"
        title_y = int(self.max_y * 0.3)
        title_x = (self.max_x - len(title)) // 2
        self.screen.addstr(title_y, title_x, title, curses.A_BOLD)
        
        msg = "Your Immutablue system has been configured successfully."
        msg_y = title_y + 2
        msg_x = (self.max_x - len(msg)) // 2
        self.screen.addstr(msg_y, msg_x, msg)
        
        reboot_msg = "The system will reboot in 5 seconds..."
        reboot_y = msg_y + 2
        reboot_x = (self.max_x - len(reboot_msg)) // 2
        self.screen.addstr(reboot_y, reboot_x, reboot_msg)
        
        self.screen.refresh()
        
        # Countdown
        for i in range(5, 0, -1):
            countdown = f"Rebooting in {i} seconds..."
            self.screen.addstr(reboot_y, reboot_x, countdown + " "*10)
            self.screen.refresh()
            sleep(1)
    
    def _mark_setup_complete(self, dry_run=False):
        """Mark setup as complete by creating the flag file.
        
        Args:
            dry_run: If True, print actions instead of executing them
        """
        if dry_run:
            # In dry-run mode, just print what would be done
            print(f"[DRY RUN] Would create directory: {os.path.dirname(COMPLETED_FLAG)}")
            print(f"[DRY RUN] Would create flag file: {COMPLETED_FLAG}")
            print(f"[DRY RUN] Flag file content: Setup completed by user {os.getenv('USER')} at {subprocess.check_output('date', shell=True, text=True).strip()}")
        else:
            # Ensure directory exists
            os.makedirs(os.path.dirname(COMPLETED_FLAG), exist_ok=True)
            
            # Create the flag file
            with open(COMPLETED_FLAG, 'w') as f:
                f.write(f"Setup completed by user {os.getenv('USER')} at {subprocess.check_output('date', shell=True, text=True).strip()}")


class DryRunMode:
    """Handler for dry-run mode which prints actions instead of executing them."""
    
    @staticmethod
    def log(action, message):
        """Log an action that would be performed in normal mode."""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[DRY RUN] [{timestamp}] {action}: {message}")
    
    @staticmethod
    def save_selections(selections):
        """Print the selections that would be saved."""
        print("[DRY RUN] Would save the following selections to settings:")
        for step_id, step_data in selections.items():
            print(f"  Step '{step_id}':")
            if isinstance(step_data, dict):
                for key, value in step_data.items():
                    print(f"    {key}: {value}")
            else:
                print(f"    {step_data}")
    
    @staticmethod
    def mark_complete():
        """Print the completion marker that would be created."""
        print(f"[DRY RUN] Would create completion flag file: {COMPLETED_FLAG}")
    
    @staticmethod
    def reboot():
        """Print the reboot action that would be performed."""
        print("[DRY RUN] Would reboot the system")


def print_help():
    """Print help information about command-line arguments."""
    prog_name = os.path.basename(sys.argv[0])
    print(f"Usage: {prog_name} [OPTIONS]")
    print("\nInteractive setup wizard for Immutablue first-boot configuration")
    print("\nOptions:")
    print("  --help                Show this help message and exit")
    print("  --dry-run             Run in dry-run mode (show actions without performing them)")
    print("  --force               Run the setup even if it has already been completed")
    print("  --no-reboot           Skip the automatic reboot at the end of setup")
    print("  --config FILE         Use a custom configuration file instead of the default hierarchy")
    print("\nDefault configuration files (in priority order):")
    print(f"  1. {USER_CONFIG_FILE}")
    print(f"  2. {SYSTEM_CONFIG_FILE}")
    print(f"  3. {DEFAULT_CONFIG_FILE}")
    print("\nFlag file used to detect completed setup:")
    print(f"  {COMPLETED_FLAG}")
    sys.exit(0)

if __name__ == "__main__":
    # Check if help is requested
    if '--help' in sys.argv or '-h' in sys.argv:
        print_help()
    
    # Process command line arguments
    dry_run = '--dry-run' in sys.argv
    force = '--force' in sys.argv
    no_reboot = '--no-reboot' in sys.argv
    
    # Check for custom config file
    config_file = None
    for i, arg in enumerate(sys.argv):
        if arg == '--config' and i + 1 < len(sys.argv):
            config_file = sys.argv[i + 1]
    
    # Check if we should skip (already completed)
    if os.path.exists(COMPLETED_FLAG) and not force:
        print("Setup already completed. Use --force to run again.")
        sys.exit(0)
    
    if dry_run:
        print("Running in DRY RUN mode - No actions will be performed")
        print("Configuration will be loaded and steps will be simulated")
        print("=" * 60)
        
        # Create an app instance just to load configuration
        app = ImmutablueTUI(config_file=config_file)
        
        # Print configuration
        print("\nWould load configuration from:")
        if config_file:
            if os.path.exists(config_file):
                print(f"  - {config_file} (custom config, exists)")
            else:
                print(f"  - {config_file} (custom config, not found)")
        else:
            for config_path in [DEFAULT_CONFIG_FILE, SYSTEM_CONFIG_FILE, USER_CONFIG_FILE]:
                if os.path.exists(config_path):
                    print(f"  - {config_path} (exists)")
                else:
                    print(f"  - {config_path} (not found)")
        
        # Print steps
        print("\nWould run the following steps:")
        for i, step in enumerate(app.config.get('steps', [])):
            print(f"  {i+1}. {step.get('title', 'Unknown step')}")
            print(f"     Type: {step.get('type', 'unknown')}")
            if step.get('type') == 'options':
                options = step.get('options', [])
                print(f"     Options: {len(options)} choices")
            elif step.get('type') == 'action':
                print(f"     Action: {step.get('action', 'unknown')}")
        
        # Simulate saving and completing
        DryRunMode.save_selections({'simulated': True})
        DryRunMode.mark_complete()
        
        if not no_reboot:
            DryRunMode.reboot()
            
        sys.exit(0)
        
    # Regular mode
    app = ImmutablueTUI(config_file=config_file)
    app.run()
    
    # After setup completes, trigger a reboot
    if not no_reboot:
        subprocess.call(["sudo", "reboot"])