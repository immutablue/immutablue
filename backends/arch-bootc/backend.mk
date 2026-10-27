# backends/arch-bootc/backend.mk -- Make defaults for BACKEND=arch-bootc.
#
# Included from makefiles/00-variables.mk before the variant logic. Arch is
# rolling: VERSION (and therefore the tag) is 'arch' rather than a release
# number, giving quay.io/immutablue/immutablue:arch, :arch-nucleus, ...
ifndef VERSION
    VERSION := arch
endif

# Re-applied by makefiles/25-backend.mk after the variant logic, which would
# otherwise point NUCLEUS and friends at Fedora base images.
BACKEND_BASE_IMAGE := docker.io/archlinux/archlinux
BACKEND_BASE_IMAGE_TAG := latest
