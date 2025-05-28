# 144-feat-brew-extension.md

## Feature: Extend Brew Package Management to Support Variants

### Issue Reference
GitLab Issue #144: feat(packages): extend brew to work with variants

### Overview
Extend the existing brew package management system in `packages.yaml` to support variant-specific package installations. This will allow different Immutablue variants (such as kuberblue, trueblue, etc.) to specify additional brew packages beyond the base set.

### Current State Analysis

#### Existing Brew Implementation
- **Location**: `scripts/packages.sh`
- **Functions**: 
  - `brew_install()` - Installs homebrew itself
  - `brew_install_all_from_yaml()` - Processes brew packages from YAML
  - `brew_install_all_packages()` - Main orchestration function
- **Architecture**: x86_64 only (ARM64 fallback to RPM packages)
- **Timing**: Runtime installation during first boot/user setup, not container build
- **Current YAML Structure**:
  ```yaml
  brew:
    install: [array of packages]
    uninstall: [array of packages]
  ```

#### Current Variant Support Pattern
The project already supports variant-specific configurations using naming patterns like:
- `rpm_[variant]` (e.g., `rpm_kuberblue`, `rpm_trueblue`)
- `services_enable_sys_[variant]`
- `flatpaks_[arch]`

### Proposed Implementation

#### 1. Extended YAML Schema
Extend `packages.yaml` brew section to support variant-specific package lists:

```yaml
brew:
  install: [base packages for all variants]
  uninstall: [base packages to remove for all variants]
  install_kuberblue: [additional packages for kuberblue]
  uninstall_kuberblue: [packages to remove for kuberblue]
  install_trueblue: [additional packages for trueblue]
  uninstall_trueblue: [packages to remove for trueblue]
  # ... additional variants as needed
```

#### 2. Code Changes Required

##### A. `scripts/packages.sh` Modifications
1. **Update `brew_install_all_from_yaml()`**:
   - Add variant detection logic (similar to existing RPM variant handling)
   - Process base `install`/`uninstall` arrays first
   - Process variant-specific `install_[variant]`/`uninstall_[variant]` arrays
   - Merge package lists appropriately

2. **Add new helper functions**:
   ```bash
   get_current_variant() {
     # Logic to detect current variant from environment/config
   }
   
   brew_get_variant_packages() {
     # Extract variant-specific packages from YAML
   }
   ```

##### B. YAML Processing Updates
- Ensure Python YAML parsing in relevant scripts handles the new structure
- Update any validation logic to accept the new schema

#### 3. Implementation Details

##### Package List Processing Logic
1. **Base packages**: Always processed from `install`/`uninstall`
2. **Variant packages**: Additional processing based on detected variant
3. **Conflict resolution**: Variant-specific uninstalls take precedence over base installs
4. **Deduplication**: Remove duplicate packages across base and variant lists

##### Variant Detection
Reuse existing variant detection mechanisms:
- Environment variables set during build
- Check for variant-specific files/configurations
- Default to base behavior if no variant detected

##### ARM64 Fallback Handling
Maintain existing behavior where ARM64 systems fallback to RPM packages:
- Variant-specific brew packages should have corresponding `rpm_aarch64_[variant]` entries
- Document requirement for ARM64 fallback packages

#### 4. Testing Strategy

##### Unit Tests
- Test YAML parsing with new schema
- Test package list merging logic
- Test variant detection

##### Integration Tests
- Test brew installation with different variants
- Test conflict resolution (package in both install and uninstall lists)
- Test ARM64 fallback behavior

##### Manual Testing
- Build different variant images
- Verify correct packages are installed for each variant
- Verify base packages are always installed

#### 5. Documentation Updates

##### User Documentation
- Update package management documentation
- Provide examples of variant-specific package configuration
- Document ARM64 fallback requirements

##### Developer Documentation
- Update build process documentation
- Document new YAML schema
- Provide migration guide for existing configurations

#### 6. Migration Considerations

##### Backward Compatibility
- Existing `brew.install` and `brew.uninstall` configurations continue to work unchanged
- New functionality is additive and optional

##### Gradual Adoption
- Variants can be migrated incrementally
- No breaking changes to existing builds

#### 7. Example Configuration

```yaml
brew:
  # Base packages for all variants
  install:
    - calc
    - coreutils
    - fastfetch
    - htop
    - neovim
  
  uninstall:
    - some-unwanted-package
  
  # Kuberblue-specific packages
  install_kuberblue:
    - kubectl
    - k9s
    - helm
    - kustomize
  
  # TrueBlue-specific packages  
  install_trueblue:
    - zfs-utils
    - sanoid
  
  uninstall_trueblue:
    - some-package-conflicting-with-zfs
```

#### 8. Implementation Timeline

1. **Phase 1**: Update YAML schema and parsing logic
2. **Phase 2**: Implement variant detection and package list processing
3. **Phase 3**: Testing and validation
4. **Phase 4**: Documentation updates

#### 9. Dependencies

- No new external dependencies required
- Leverages existing YAML processing infrastructure
- Uses existing variant detection patterns

#### 10. Risks and Mitigations

##### Risk: Package Conflicts
- **Mitigation**: Implement clear precedence rules (variant uninstalls > base installs)
- **Mitigation**: Add validation to detect conflicts during build

##### Risk: ARM64 Compatibility
- **Mitigation**: Maintain existing fallback behavior
- **Mitigation**: Document ARM64 package requirements clearly

##### Risk: Build Performance Impact
- **Mitigation**: Minimal impact as brew installation happens at runtime, not build time
- **Mitigation**: Optimize package list processing to avoid redundant operations

### Success Criteria

1. Variant-specific brew packages can be defined in `packages.yaml`
2. Base brew packages continue to work unchanged
3. Package conflicts are resolved predictably
4. ARM64 fallback behavior is maintained
5. All existing tests pass
6. Documentation is updated appropriately

### Future Enhancements

- Support for architecture-specific variant packages (`install_kuberblue_x86_64`)
- Dynamic package selection based on detected hardware/environment
- Package dependency resolution and ordering