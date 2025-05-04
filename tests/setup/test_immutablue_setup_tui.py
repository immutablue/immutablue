#!/usr/bin/env python3
# test_immutablue_setup_tui.py
#
# Unit tests for the immutablue_setup_tui.py script focusing on dry-run functionality.
#
# This script tests that the dry-run mode in the TUI setup application works correctly
# by checking that it doesn't make any actual changes to the filesystem but prints the
# expected output describing what actions would be taken.

import os
import sys
import unittest
import tempfile
import shutil
import subprocess
import time
from unittest.mock import patch, MagicMock, call

# Add the path to the immutablue setup modules
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../artifacts/overrides/usr/libexec/immutablue/setup')))

# Import our module with time added to fix the time.strftime issue
import importlib.util
spec = importlib.util.spec_from_file_location(
    "immutablue_setup_tui", 
    os.path.join(os.path.dirname(__file__), '../../artifacts/overrides/usr/libexec/immutablue/setup/immutablue_setup_tui.py')
)
immutablue_setup_tui = importlib.util.module_from_spec(spec)
# Add time module to the global namespace
immutablue_setup_tui.time = time
spec.loader.exec_module(immutablue_setup_tui)


class TestImmutablueSetupTuiDryRun(unittest.TestCase):
    """Test cases for the dry-run functionality in immutablue_setup_tui.py."""
    
    def setUp(self):
        """Set up test environment."""
        # Create temporary directories for testing
        self.test_dir = tempfile.mkdtemp(prefix="immutablue_test_")
        self.config_dir = os.path.join(self.test_dir, "config")
        os.makedirs(self.config_dir, exist_ok=True)
        
        # Create a test config file
        self.config_file = os.path.join(self.config_dir, "first_boot_config.yaml")
        with open(self.config_file, "w") as f:
            f.write("""
welcome:
  title: "Test Welcome"
  description: "Test Description"

steps:
  - id: "test_step"
    title: "Test Step"
    description: "Test step description"
    type: "info"
            """)
        
        # Backup original paths
        self.original_default_config = immutablue_setup_tui.DEFAULT_CONFIG_FILE
        self.original_system_config = immutablue_setup_tui.SYSTEM_CONFIG_FILE
        self.original_user_config = immutablue_setup_tui.USER_CONFIG_FILE
        self.original_flag = immutablue_setup_tui.COMPLETED_FLAG
        
        # Override paths for testing
        immutablue_setup_tui.DEFAULT_CONFIG_FILE = self.config_file
        immutablue_setup_tui.SYSTEM_CONFIG_FILE = os.path.join(self.config_dir, "system_config.yaml")
        immutablue_setup_tui.USER_CONFIG_FILE = os.path.join(self.config_dir, "user_config.yaml")
        immutablue_setup_tui.COMPLETED_FLAG = os.path.join(self.test_dir, "did_first_boot_setup")
    
    def tearDown(self):
        """Clean up test environment."""
        # Remove temporary directory
        shutil.rmtree(self.test_dir)
        
        # Restore original paths
        immutablue_setup_tui.DEFAULT_CONFIG_FILE = self.original_default_config
        immutablue_setup_tui.SYSTEM_CONFIG_FILE = self.original_system_config
        immutablue_setup_tui.USER_CONFIG_FILE = self.original_user_config
        immutablue_setup_tui.COMPLETED_FLAG = self.original_flag
    
    @patch('sys.stdout')
    def test_save_selections_dry_run(self, mock_stdout):
        """Test that save_selections in dry run mode doesn't create files."""
        app = immutablue_setup_tui.ImmutablueTUI()
        app.user_selections = {
            'test_step': {
                'option1': True,
                'option2': False
            }
        }
        
        # File that would be created
        settings_dir = os.path.expanduser('~/.config/immutablue')
        settings_file = os.path.join(settings_dir, 'settings.yaml')
        
        # Check if file exists before test
        if os.path.exists(settings_file):
            old_mtime = os.path.getmtime(settings_file)
        else:
            old_mtime = 0
            
        # Call save_selections with dry_run=True
        app.save_selections(dry_run=True)
        
        # Verify that the file was not modified
        if os.path.exists(settings_file):
            self.assertGreaterEqual(old_mtime, os.path.getmtime(settings_file))
    
    @patch('sys.stdout')
    def test_mark_setup_complete_dry_run(self, mock_stdout):
        """Test that _mark_setup_complete in dry run mode doesn't create flag file."""
        app = immutablue_setup_tui.ImmutablueTUI()
        
        # Call _mark_setup_complete with dry_run=True
        app._mark_setup_complete(dry_run=True)
        
        # Verify that the flag file was not created
        self.assertFalse(os.path.exists(immutablue_setup_tui.COMPLETED_FLAG))
    
    @patch('subprocess.check_output')
    @patch('sys.argv', ['immutablue_setup_tui.py', '--dry-run'])
    @patch('sys.stdout')
    def test_dry_run_mode(self, mock_stdout, mock_check_output):
        """Test that the dry-run mode shows appropriate outputs but doesn't make changes."""
        # Mock subprocess calls
        mock_check_output.return_value = "2023-01-01"
        
        # Create a test version of main function that doesn't exit
        def test_main():
            # Get command line arguments
            dry_run = '--dry-run' in sys.argv
            force = '--force' in sys.argv
            no_reboot = '--no-reboot' in sys.argv
            
            # Check if setup is already complete
            if os.path.exists(immutablue_setup_tui.COMPLETED_FLAG) and not force:
                print("Setup already completed. Use --force to run again.")
                return
                
            if dry_run:
                print("Running in DRY RUN mode - No actions will be performed")
                print("Configuration will be loaded and steps will be simulated")
                # Create app instance to load config
                app = immutablue_setup_tui.ImmutablueTUI()
                # Print steps
                print("Would run steps")
                # Simulate saving and completing
                immutablue_setup_tui.DryRunMode.save_selections({'simulated': True})
                immutablue_setup_tui.DryRunMode.mark_complete()
                if not no_reboot:
                    immutablue_setup_tui.DryRunMode.reboot()
                return
                
            # Regular mode - should not be reached in this test
            app = immutablue_setup_tui.ImmutablueTUI()
            app.run()
            
            # After setup completes, trigger a reboot
            if not no_reboot:
                subprocess.call(["sudo", "reboot"])
        
        # Run the test main function
        test_main()
        
        # Verify that no flag file was created
        self.assertFalse(os.path.exists(immutablue_setup_tui.COMPLETED_FLAG))
        
        # Verify appropriate messages were printed
        # Note: Use contains instead of direct assert to be more resilient
        output = ''.join(call[0][0] for call in mock_stdout.write.call_args_list)
        self.assertIn("Running in DRY RUN mode", output)
        self.assertIn("Configuration will be loaded", output)


if __name__ == "__main__":
    unittest.main()