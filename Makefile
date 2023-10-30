.PHONY: %-build build patch %-all-patch %-clean clean help

all: help

ROOTDIR := $(realpath .)
GO_BUILD := GOOS=darwin go build

UNAME := $(shell uname -s)

AWK := awk
ifeq ($(UNAME), Darwin)
	AWK = gawk
endif

CODESIGN_IDENTITY ?= -

##@
##@ Build commands
##@

%-build: ##@ Build gvproxy or vfkit. e.g.
         ##@ gvproxy-amd64-build / gvproxy-arm64-build
         ##@ vfkit-amd64-build / vfkit-arm64-build
	$(eval _DIR := $(firstword $(subst -, ,$*)))
	$(eval _ARCH := $(word 2, $(subst -, ,$*)))

	@case $(_DIR) in \
		gvproxy) \
			GOARCH=$(_ARCH) $(GO_BUILD) -C $(ROOTDIR)/gvproxy/ -ldflags '-s -w' -o $(ROOTDIR)/out/gvproxy-$(_ARCH) ./cmd/gvproxy; \
			;; \
		vfkit) \
			CGO_ENABLED=1 CGO_CFLAGS=-mmacosx-version-min=12.3 GOARCH=$(_ARCH) $(GO_BUILD) -C $(ROOTDIR)/vfkit/ -o $(ROOTDIR)/out/vfkit-$(_ARCH) ./cmd/vfkit; \
			if [[ "$(UNAME)" = "Darwin" ]]; then \
				codesign --force --options runtime --entitlements $(ROOTDIR)/vfkit/vf.entitlements --sign $(CODESIGN_IDENTITY) $(ROOTDIR)/out/vfkit-$(_ARCH); \
				codesign -vv -d $(ROOTDIR)/out/vfkit-$(_ARCH); \
			fi; \
			;; \
		*) \
			printf "Please specify a build command\n"; \
			exit 1; \
			;; \
		esac \

build: ##@ Build all arch gvproxy and vfkit
	$(MAKE) gvproxy-amd64-build
	$(MAKE) gvproxy-arm64-build
	$(MAKE) vfkit-amd64-build
	$(MAKE) vfkit-arm64-build

##@
##@ Patch commands
##@

patch: ##@ Patch submodules projects
       ##@ e.g. make patch apply=gvproxy / make patch export=vfkit / make patch reset=vfkit
ifdef apply
	@./tools/patch.py --apply $(apply)
else
    ifdef export
		@./tools/patch.py --export $(export)
    else
        ifdef reset
			@./tools/patch.py --reset $(reset)
        else
			$(error Please specify a patch command)
        endif
    endif
endif

%-all-patch: ##@ Patch all submodules projects
           ##@ e.g. make apply-all-patch / make export-all-patch / make reset-all-patch
	@./tools/patch.py --$* gvproxy
	@./tools/patch.py --$* vfkit

##@
##@ Clean build files commands
##@

%-clean: ##@ Clean gvproxy or vfkit files with specified architecture
         ##@ e.g. gvproxy-amd64-clean / gvproxy-arm64-clean / vfkit-amd64-clean / vfkit-arm64-clean
	$(eval _DIR := $(firstword $(subst -, ,$*)))
	$(eval _ARCH := $(word 2, $(subst -, ,$*)))

	$(RM) $(ROOTDIR)/out/$(_DIR)-$(_ARCH)

clean: ##@ Clean all build files
	$(MAKE) gvproxy-amd64-clean
	$(MAKE) gvproxy-arm64-clean
	$(MAKE) vfkit-amd64-clean
	$(MAKE) vfkit-arm64-clean

##@
##@ Misc commands
##@

help: ##@ (Default) Print listing of key targets with their descriptions
	@printf "\nUsage: make <command>\n"
	@if [[ -z $(shell which $(AWK) 2> /dev/null) ]]; then \
		printf "$(AWK) not found\n"; \
		exit 1; \
	fi; \

	@grep -F -h "##@" $(MAKEFILE_LIST) | grep -F -v grep -F | sed -e 's/\\$$//' | $(AWK) 'BEGIN {FS = ":*[[:space:]]*##@[[:space:]]*"}; \
	{ \
		if($$2 == "") \
			pass; \
		else if($$0 ~ /^#/) \
			printf "\n%s\n", $$2; \
		else if($$1 == "") \
			printf "     %-20s%s\n", "", $$2; \
		else \
			printf "\n    \033[34m%-20s\033[0m %s\n", $$1, $$2; \
	}'
