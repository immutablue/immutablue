# ==============================================================================
# Immutablue Build System - Backends Built in a VM
# ==============================================================================
# A backend that cannot be built on this host sets BACKEND_VM in its
# backend.mk to a script with a 'delegate' command (freebsd-be on Linux:
# backends/freebsd-be/builder-vm.sh). The targets that build, test or push
# its images then run 'make <target>' inside that VM against a fresh sync of
# this checkout, with the same command-line variables; the script finds and
# starts the VM, and prints how to create it when there is none. Their usual
# recipes (30-build.mk, 50-tests.mk) are skipped. Everything else -- pre_test,
# docs, iso (make-iso.sh delegates by itself) -- still runs here.
#
#   make FREEBSD=1 NUCLEUS=1 build        # built in the builder VM
#   make FREEBSD=1 all                    # build, test and push there
#
# Pushing runs as root in the VM, which needs its own registry login; the
# push targets check for it first and say how (builder-vm.sh ssh, then
# 'sudo podman login <registry>').
# ==============================================================================

ifdef BACKEND_VM

# The registry the image goes to: quay.io for quay.io/immutablue/immutablue.
BACKEND_VM_REGISTRY := $(firstword $(subst /, ,$(IMAGE)))

# Passed to the VM's make: the backend and every variable given on this
# command line (FREEBSD=1, NUCLEUS=1, ...).
BACKEND_VM_ARGS := BACKEND=$(BACKEND) $(MAKEOVERRIDES)

.PHONY: build build-deps test run_all_tests test_container test_package_presence test_container_qemu test_artifacts test_setup push push-deps

build build-deps test run_all_tests test_container test_package_presence test_container_qemu test_artifacts test_setup:
	@bash $(BACKEND_VM) delegate $(BACKEND_VM_ARGS) $@

push push-deps:
	@bash $(BACKEND_VM) delegate --push $(BACKEND_VM_REGISTRY) $(BACKEND_VM_ARGS) $@

endif
