#!/usr/bin/python3
# immutablue_setup_gui.py
#
# This script provides a graphical user interface (GUI) for the Immutablue
# first-boot setup experience. It guides users through initial system configuration
# with a friendly and intuitive interface when running on systems with a graphical 
# environment (non-nucleus builds).
#
# The GUI application follows a step-by-step wizard approach for:
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
import time
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib, Gdk, Gio
from pathlib import Path
import threading

# Paths for configuration files
DEFAULT_CONFIG_FILE = '/usr/immutablue/setup/first_boot_config.yaml'
SYSTEM_CONFIG_FILE = '/etc/immutablue/setup/first_boot_config.yaml'
USER_CONFIG_FILE = os.path.expanduser('~/.config/immutablue/first_boot_config.yaml')

# Flag file to track completion
COMPLETED_FLAG = '/etc/immutablue/setup/did_first_boot_setup'

class ImmutableSetupWindow(Gtk.ApplicationWindow):
    """Main window for the Immutablue setup application."""
    
    def __init__(self, app, config_file=None):
        """Initialize the application window.
        
        Args:
            app: The parent application
            config_file: Optional path to a custom config file that overrides the default hierarchy
        """
        super().__init__(application=app, title="Immutablue Setup")
        
        # Set default window size
        self.set_default_size(800, 600)
        
        # Center window on screen
        self.set_resizable(True)
        
        # Store custom config file path
        self.custom_config_file = config_file
        
        # Load configuration
        self.config = self.load_config()
        self.user_selections = {}
        self.current_step = -1  # Start with welcome page
        
        # Create header bar
        self.header = Gtk.HeaderBar()
        self.set_titlebar(self.header)
        
        # Main container
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.set_child(self.main_box)
        
        # Content area
        self.content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        self.content_box.set_margin_top(30)
        self.content_box.set_margin_bottom(20)
        self.content_box.set_margin_start(30)
        self.content_box.set_margin_end(30)
        self.main_box.append(self.content_box)
        
        # Button area at bottom
        self.button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.button_box.set_halign(Gtk.Align.END)
        self.button_box.set_margin_top(10)
        self.button_box.set_margin_bottom(20)
        self.button_box.set_margin_start(30)
        self.button_box.set_margin_end(30)
        self.main_box.append(self.button_box)
        
        # Back button
        self.back_button = Gtk.Button(label="Back")
        self.back_button.connect("clicked", self.on_back_clicked)
        self.button_box.append(self.back_button)
        
        # Next button
        self.next_button = Gtk.Button(label="Next")
        self.next_button.connect("clicked", self.on_next_clicked)
        self.button_box.append(self.next_button)
        
        # Show welcome page
        self.show_welcome()
    
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
    
    def clear_content(self):
        """Clear all widgets from the content area."""
        while True:
            child = self.content_box.get_first_child()
            if child:
                self.content_box.remove(child)
            else:
                break
    
    def show_welcome(self):
        """Display the welcome screen."""
        self.clear_content()
        welcome = self.config.get('welcome', {})
        
        # Title
        title_label = Gtk.Label(label=welcome.get('title', 'Welcome to Immutablue'))
        title_label.set_halign(Gtk.Align.CENTER)
        title_label.add_css_class("title-1")
        self.content_box.append(title_label)
        
        # Logo (if available)
        logo_path = welcome.get('logo', '/usr/share/pixmaps/fedora-logo.png')
        if os.path.exists(logo_path):
            logo = Gtk.Picture.new_for_filename(logo_path)
            logo.set_size_request(200, 200)
            logo.set_halign(Gtk.Align.CENTER)
            self.content_box.append(logo)
        
        # Description
        desc_label = Gtk.Label(label=welcome.get('description', 'This setup will guide you through configuring your new Immutablue system.'))
        desc_label.set_wrap(True)
        desc_label.set_max_width_chars(60)
        desc_label.set_halign(Gtk.Align.CENTER)
        desc_label.set_margin_top(20)
        self.content_box.append(desc_label)
        
        # Configure buttons for welcome page
        self.back_button.set_sensitive(False)
        self.next_button.set_sensitive(True)
        self.next_button.set_label("Begin Setup")
    
    def on_next_clicked(self, button):
        """Handle next button clicks."""
        if self.current_step == -1:
            # Moving from welcome to first step
            self.current_step = 0
            self.show_step(self.current_step)
        elif self.current_step < len(self.config['steps']) - 1:
            # Moving to next step
            self.current_step += 1
            self.show_step(self.current_step)
        else:
            # Final step - complete setup
            self.complete_setup()
    
    def on_back_clicked(self, button):
        """Handle back button clicks."""
        if self.current_step > 0:
            self.current_step -= 1
            self.show_step(self.current_step)
        elif self.current_step == 0:
            # Go back to welcome
            self.current_step = -1
            self.show_welcome()
    
    def show_step(self, step_index):
        """Display a specific setup step."""
        step = self.config['steps'][step_index]
        self.clear_content()
        
        # Title
        title_label = Gtk.Label(label=step['title'])
        title_label.set_halign(Gtk.Align.START)
        title_label.add_css_class("title-2")
        self.content_box.append(title_label)
        
        # Description
        desc_label = Gtk.Label(label=step['description'])
        desc_label.set_wrap(True)
        desc_label.set_max_width_chars(80)
        desc_label.set_halign(Gtk.Align.START)
        desc_label.set_margin_top(10)
        desc_label.set_margin_bottom(20)
        self.content_box.append(desc_label)
        
        # Configure back button
        self.back_button.set_sensitive(True)
        
        # Handle different step types
        if step['type'] == 'info':
            self.setup_info_step(step)
        elif step['type'] == 'options':
            self.setup_options_step(step)
        elif step['type'] == 'action':
            self.setup_action_step(step)
        
        # Configure next button label for last step
        if step_index == len(self.config['steps']) - 1:
            self.next_button.set_label("Finish")
        else:
            self.next_button.set_label("Next")
    
    def setup_info_step(self, step):
        """Set up an informational step."""
        # Info steps just show text and maybe an image
        if 'image' in step and os.path.exists(step['image']):
            image = Gtk.Picture.new_for_filename(step['image'])
            image.set_halign(Gtk.Align.CENTER)
            self.content_box.append(image)
        
        self.next_button.set_sensitive(True)
    
    def setup_options_step(self, step):
        """Set up a step with selectable options."""
        step_id = step.get('id', f'step_{self.current_step}')
        options = step.get('options', [])
        
        # Initialize selected options if not already set
        if step_id not in self.user_selections:
            self.user_selections[step_id] = {}
            for option in options:
                self.user_selections[step_id][option['id']] = option.get('default', False)
        
        # Create a scrolled window for options
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_min_content_height(300)
        
        # Container for options
        options_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        options_box.set_margin_start(10)
        options_box.set_margin_end(10)
        scrolled.set_child(options_box)
        
        # Add each option
        for option in options:
            # Option container
            option_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
            option_box.set_margin_bottom(15)
            
            # Checkbox for the option
            checkbox = Gtk.CheckButton(label=option['label'])
            checkbox.set_active(self.user_selections[step_id][option['id']])
            
            # Connect the toggled signal
            checkbox.connect('toggled', self.on_option_toggled, step_id, option['id'])
            
            option_box.append(checkbox)
            
            # Description if available
            if 'description' in option:
                desc = Gtk.Label(label=option['description'])
                desc.set_wrap(True)
                desc.set_halign(Gtk.Align.START)
                desc.set_margin_start(25)
                desc.add_css_class("caption")
                option_box.append(desc)
            
            options_box.append(option_box)
        
        self.content_box.append(scrolled)
        self.next_button.set_sensitive(True)
    
    def on_option_toggled(self, checkbox, step_id, option_id):
        """Handle option checkbox toggling."""
        self.user_selections[step_id][option_id] = checkbox.get_active()
    
    def setup_action_step(self, step):
        """Set up an action step that performs a task."""
        # Progress area
        progress_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        progress_box.set_margin_top(10)
        self.content_box.append(progress_box)
        
        # Progress bar
        progress_bar = Gtk.ProgressBar()
        progress_bar.set_fraction(0.1)
        progress_bar.set_show_text(True)
        progress_bar.set_text("Working...")
        progress_bar.set_margin_top(10)
        progress_box.append(progress_bar)
        
        # Status label
        status_label = Gtk.Label(label="Starting...")
        status_label.set_halign(Gtk.Align.START)
        status_label.set_margin_top(10)
        progress_box.append(status_label)
        
        # Results area (scrollable)
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_min_content_height(200)
        
        results_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        results_box.set_margin_start(10)
        results_box.set_margin_end(10)
        scrolled.set_child(results_box)
        progress_box.append(scrolled)
        
        # Disable navigation while working
        self.back_button.set_sensitive(False)
        self.next_button.set_sensitive(False)
        
        # Start the action in a separate thread
        action_type = step.get('action', '')
        thread = threading.Thread(
            target=self.run_action,
            args=(action_type, progress_bar, status_label, results_box)
        )
        thread.daemon = True
        thread.start()
    
    def run_action(self, action_type, progress_bar, status_label, results_box):
        """Run an action in a background thread."""
        step_id = self.config['steps'][self.current_step].get('id', f'step_{self.current_step}')
        results = []
        
        try:
            # Initialize results for this step
            self.user_selections[step_id] = {'completed': False}
            
            # Update progress periodically
            def update_progress(fraction, text):
                GLib.idle_add(progress_bar.set_fraction, fraction)
                GLib.idle_add(progress_bar.set_text, text)
            
            # Update status
            def update_status(text):
                GLib.idle_add(status_label.set_text, text)
            
            # Add a result
            def add_result(text):
                results.append(text)
                label = Gtk.Label(label=text)
                label.set_halign(Gtk.Align.START)
                label.set_wrap(True)
                GLib.idle_add(results_box.append, label)
            
            # Perform the appropriate action
            if action_type == 'hardware_detection':
                # Hardware detection
                update_progress(0.1, "Detecting CPU...")
                update_status("Scanning hardware information...")
                
                try:
                    # Get CPU info
                    cpu_info = subprocess.check_output("lscpu | grep 'Model name'", 
                                                      shell=True, text=True).strip()
                    add_result(cpu_info)
                    self.user_selections[step_id]['cpu'] = cpu_info
                    time.sleep(0.5)
                except Exception as e:
                    add_result(f"Error detecting CPU: {str(e)}")
                
                update_progress(0.3, "Detecting Memory...")
                
                try:
                    # Get memory info
                    mem_info = subprocess.check_output("free -h | grep Mem:", 
                                                     shell=True, text=True).strip()
                    add_result(mem_info)
                    self.user_selections[step_id]['memory'] = mem_info
                    time.sleep(0.5)
                except Exception as e:
                    add_result(f"Error detecting memory: {str(e)}")
                
                update_progress(0.5, "Detecting GPU...")
                
                try:
                    # Get GPU info
                    gpu_info = subprocess.check_output("lspci | grep -i vga", 
                                                     shell=True, text=True).strip()
                    add_result(gpu_info)
                    self.user_selections[step_id]['gpu'] = gpu_info
                    time.sleep(0.5)
                except Exception as e:
                    add_result(f"Error detecting GPU: {str(e)}")
                
                update_progress(0.7, "Detecting Storage...")
                
                try:
                    # Get disk info
                    disk_info = subprocess.check_output("df -h / | tail -n 1", 
                                                      shell=True, text=True).strip()
                    add_result(f"Root filesystem: {disk_info}")
                    self.user_selections[step_id]['storage'] = disk_info
                    time.sleep(0.5)
                except Exception as e:
                    add_result(f"Error detecting storage: {str(e)}")
                
                # Finalize hardware detection
                update_progress(1.0, "Hardware detection complete")
                update_status("Hardware detection completed successfully")
                
            elif action_type == 'network_setup':
                # Network setup
                update_progress(0.1, "Checking connectivity...")
                update_status("Testing network connectivity...")
                
                try:
                    # Check internet connectivity
                    result = subprocess.run(["ping", "-c", "1", "-W", "2", "9.9.9.9"], 
                                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    
                    if result.returncode == 0:
                        add_result("✓ Internet connection available")
                        self.user_selections[step_id]['internet'] = True
                    else:
                        add_result("✗ No internet connection")
                        self.user_selections[step_id]['internet'] = False
                    
                    time.sleep(0.5)
                except Exception as e:
                    add_result(f"Error checking connectivity: {str(e)}")
                
                update_progress(0.4, "Checking interfaces...")
                
                try:
                    # Get network interfaces
                    interfaces_output = subprocess.check_output(
                        "ip -o link show | awk -F': ' '{print $2}'", 
                        shell=True, text=True).strip()
                    
                    interfaces = interfaces_output.split('\n')
                    add_result("Network interfaces:")
                    
                    for interface in interfaces:
                        if interface != 'lo':  # Skip loopback
                            add_result(f"  - {interface}")
                    
                    self.user_selections[step_id]['interfaces'] = interfaces
                    time.sleep(0.5)
                except Exception as e:
                    add_result(f"Error detecting network interfaces: {str(e)}")
                
                update_progress(0.7, "Checking hostname...")
                
                try:
                    # Get hostname
                    hostname = subprocess.check_output("hostname", shell=True, text=True).strip()
                    add_result(f"Hostname: {hostname}")
                    self.user_selections[step_id]['hostname'] = hostname
                    time.sleep(0.5)
                except Exception as e:
                    add_result(f"Error getting hostname: {str(e)}")
                
                # Finalize network setup
                update_progress(1.0, "Network setup complete")
                update_status("Network configuration completed")
                
            else:
                # Generic action - just wait a bit to simulate work
                for i in range(10):
                    fraction = (i + 1) / 10
                    update_progress(fraction, f"Working... {int(fraction * 100)}%")
                    update_status(f"Performing task {i+1}/10")
                    time.sleep(0.5)
                
                update_progress(1.0, "Task complete")
                update_status("Operation completed successfully")
            
            # Mark as completed
            self.user_selections[step_id]['completed'] = True
            
        except Exception as e:
            # Handle any unexpected errors
            GLib.idle_add(status_label.set_text, f"Error: {str(e)}")
            self.user_selections[step_id]['error'] = str(e)
        
        # Re-enable navigation
        GLib.idle_add(self.back_button.set_sensitive, True)
        GLib.idle_add(self.next_button.set_sensitive, True)
    
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
    
    def complete_setup(self, dry_run=False):
        """Complete the setup process.
        
        Args:
            dry_run: If True, print actions instead of executing them
        """
        # Save all user selections
        self.save_selections(dry_run)
        
        if dry_run:
            # In dry-run mode, just print what would be done
            print(f"[DRY RUN] Would create directory: {os.path.dirname(COMPLETED_FLAG)}")
            print(f"[DRY RUN] Would create flag file: {COMPLETED_FLAG}")
            print(f"[DRY RUN] Flag file content: Setup completed by user {os.getenv('USER')} at {subprocess.check_output('date', shell=True, text=True).strip()}")
            print("[DRY RUN] Would display completion dialog")
            print("[DRY RUN] Would reboot system (if --no-reboot not specified)")
        else:
            # Mark setup as complete by creating flag file
            os.makedirs(os.path.dirname(COMPLETED_FLAG), exist_ok=True)
            with open(COMPLETED_FLAG, 'w') as f:
                f.write(f"Setup completed by user {os.getenv('USER')} at {subprocess.check_output('date', shell=True, text=True).strip()}")
            
            # Show completion dialog
            dialog = Gtk.MessageDialog(
                transient_for=self,
                modal=True,
                message_type=Gtk.MessageType.INFO,
                buttons=Gtk.ButtonsType.OK,
                text="Setup Complete"
            )
            dialog.format_secondary_text(
                "Your Immutablue system has been configured successfully. The system will reboot to apply settings."
            )
            dialog.connect("response", self.on_completion_dialog_response)
            dialog.show()
    
    def on_completion_dialog_response(self, dialog, response):
        """Handle completion dialog response."""
        dialog.destroy()
        
        # Schedule reboot
        if '--no-reboot' not in sys.argv:
            subprocess.Popen(["sudo", "reboot"])
        
        # Quit the application
        self.get_application().quit()


def print_help():
    """Print help information about command-line arguments."""
    prog_name = os.path.basename(sys.argv[0])
    print(f"Usage: {prog_name} [OPTIONS]")
    print("\nGraphical setup wizard for Immutablue first-boot configuration")
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

class ImmutableSetupApp(Gtk.Application):
    """Immutablue setup application."""
    
    def __init__(self):
        """Initialize the application."""
        # Check if help is requested before initializing GTK
        if '--help' in sys.argv or '-h' in sys.argv:
            print_help()
            
        super().__init__(application_id="org.immutablue.setup", flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE)
        
        # Store these at app level since they need to be accessed from multiple methods
        self.dry_run = False
        self.force = False
        self.config_file = None
        self.no_reboot = False
        
    def do_command_line(self, command_line):
        """Handle command line arguments."""
        args = command_line.get_arguments()
        
        # Process our custom arguments
        if '--dry-run' in args:
            self.dry_run = True
        
        if '--force' in args:
            self.force = True
            
        if '--no-reboot' in args:
            self.no_reboot = True
            
        # Check for custom config file
        for i, arg in enumerate(args):
            if arg == '--config' and i + 1 < len(args):
                self.config_file = args[i + 1]
                
        # Help should already be handled before GTK initialization
        if '--help' in args or '-h' in args:
            self.quit()
            return 0
        
        # Activate the application with our processed arguments
        self.activate()
        return 0
        
    def do_activate(self):
        """Called when the application is activated."""
        # Check for dry run mode
        if self.dry_run:
            print("Running in DRY RUN mode - No actions will be performed")
            print("Configuration will be loaded and steps will be simulated")
            print("=" * 60)
            
            # Create an app instance just to load configuration
            win = ImmutableSetupWindow(self, config_file=self.config_file)
            
            # Print configuration
            print("\nWould load configuration from:")
            if self.config_file:
                if os.path.exists(self.config_file):
                    print(f"  - {self.config_file} (custom config, exists)")
                else:
                    print(f"  - {self.config_file} (custom config, not found)")
            else:
                for config_path in [DEFAULT_CONFIG_FILE, SYSTEM_CONFIG_FILE, USER_CONFIG_FILE]:
                    if os.path.exists(config_path):
                        print(f"  - {config_path} (exists)")
                    else:
                        print(f"  - {config_path} (not found)")
            
            # Print steps
            print("\nWould run the following steps:")
            for i, step in enumerate(win.config.get('steps', [])):
                print(f"  {i+1}. {step.get('title', 'Unknown step')}")
                print(f"     Type: {step.get('type', 'unknown')}")
                if step.get('type') == 'options':
                    options = step.get('options', [])
                    print(f"     Options: {len(options)} choices")
                elif step.get('type') == 'action':
                    print(f"     Action: {step.get('action', 'unknown')}")
            
            # Simulate completion
            win.complete_setup(dry_run=True)
            
            # If not rebooting, indicate that
            if self.no_reboot:
                print("[DRY RUN] Reboot skipped due to --no-reboot flag")
            
            # Quit the application
            self.quit()
            return
        
        # Check if we should skip (already completed)
        if os.path.exists(COMPLETED_FLAG) and not self.force:
            # Show a message dialog
            dialog = Gtk.MessageDialog(
                transient_for=None,
                modal=True,
                message_type=Gtk.MessageType.INFO,
                buttons=Gtk.ButtonsType.OK,
                text="Setup Already Completed"
            )
            dialog.format_secondary_text(
                "The Immutablue setup has already been completed. Use --force to run again."
            )
            dialog.connect("response", lambda dialog, response: self.quit())
            dialog.show()
            return
            
        # Create the window
        win = ImmutableSetupWindow(self, config_file=self.config_file)
        win.present()


if __name__ == "__main__":
    app = ImmutableSetupApp()
    app.run(sys.argv)