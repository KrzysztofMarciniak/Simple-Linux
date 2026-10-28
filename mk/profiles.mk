# ---- profile targets -------------------------------------------------------
bare:
	@$(MAKE) --no-print-directory PROFILE=bare iso

# Ask for the passwords first (before the long build), then build.
minimal:
	@rm -f $(CREDS)
	@$(MAKE) --no-print-directory PROFILE=minimal $(CREDS)
	@$(MAKE) --no-print-directory PROFILE=minimal iso

# Remember which profile the rootfs was generated for.
$(STAMP)/profile: FORCE
	@mkdir -p $(STAMP)
	@echo '$(PROFILE)' | cmp -s - $@ || echo '$(PROFILE)' > $@

# Stores only SHA-512 crypt hashes (line 1: root, line 2: $(MIN_USER)).
$(CREDS):
	@mkdir -p $(B)
	@set -e; \
	[ -t 0 ] || { echo 'make minimal needs an interactive terminal for the password prompts' >&2; exit 1; }; \
	hash() { \
	  if command -v openssl >/dev/null 2>&1; then openssl passwd -6 -stdin; \
	  elif command -v mkpasswd >/dev/null 2>&1; then mkpasswd -m sha-512 -s; \
	  else echo 'error: openssl or mkpasswd is required on the host' >&2; return 1; fi; \
	}; \
	ask() { \
	  while :; do \
	    printf '%s: ' "$$1" >&2; read -r -s p1; echo >&2; \
	    if [ -z "$$p1" ]; then echo 'Password must not be empty.' >&2; continue; fi; \
	    printf 'Retype %s: ' "$$1" >&2; read -r -s p2; echo >&2; \
	    [ "$$p1" = "$$p2" ] && break; \
	    echo 'Passwords do not match, try again.' >&2; \
	  done; \
	  printf '%s' "$$p1" | hash; \
	}; \
	echo 'Minimal profile: user $(MIN_USER), hostname $(MIN_HOSTNAME)' >&2; \
	rh=$$(ask 'Root password'); \
	uh=$$(ask 'Password for $(MIN_USER)'); \
	( umask 077; printf '%s\n%s\n' "$$rh" "$$uh" > $@.tmp ); \
	mv $@.tmp $@
